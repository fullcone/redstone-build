#!/bin/bash
# Same hybrid as build-510-hybrid-with-66.sh but with 6.12 vmlinux instead of 6.6
set -eu

OUT=/mnt/nvme/immortalwrt/redstone-fit
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
KERNEL612=$(ls -d /mnt/nvme/linux-612/linux-6.12.* 2>/dev/null | head -1)
mkdir -p "$OUT"
cd "$OUT"

if [ -z "$KERNEL612" ] || [ ! -f "$KERNEL612/vmlinux" ]; then
    echo "ERROR: 6.12 vmlinux not built yet ($KERNEL612)"
    exit 1
fi

rm -rf stage
mkdir -p stage/opt stage/usr/sbin stage/usr/lib
cp -f "$KERNEL612/vmlinux"                                                                                                                                  stage/opt/vmlinux-612
cp -f dtb66.dtb                                                                                                                                              stage/opt/dtb-612
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio stage/opt/initramfs-612
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/build/sbin/kexec stage/usr/sbin/kexec
chmod +x stage/usr/sbin/kexec
LIBZ=$(find /mnt/nvme/openwrt-2203/staging_dir/target-powerpc_8540_musl -name "libz.so*" 2>/dev/null | head -3)
for f in $LIBZ; do cp -af "$f" stage/usr/lib/ ; done

cd stage; find . | cpio -o -H newc > ../extra-612.cpio 2>/dev/null; cd ..
cat /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio extra-612.cpio > combined-612.cpio

cp -f /tmp/edgenos-510-kexec.bin ek510.bin
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb -o /tmp/c.dts 2>/dev/null
dtc -I dts -O dtb -p 0x1000 /tmp/c.dts -o edtb-510.dtb 2>/dev/null

cat > combined-612.its <<'ITS'
/dts-v1/;
/ {
    description = "5.10 hybrid + 6.12 files in /opt for kexec";
    #address-cells = <0x01>;
    images {
        kernel { description = "EdgeNOS 5.10 KEXEC"; data = /incbin/("ek510.bin");
            type = "kernel"; arch = "ppc"; os = "linux"; compression = "none";
            load = <0x00>; entry = <0x00>; };
        initramfs { description = "5.10 initramfs + /opt 6.12 files";
            data = /incbin/("combined-612.cpio");
            type = "ramdisk"; arch = "ppc"; os = "linux"; compression = "none"; load = <0x00>; };
        fdt { description = "EdgeNOS dtb padded"; data = /incbin/("edtb-510.dtb");
            type = "flat_dt"; arch = "ppc"; os = "linux"; compression = "none"; };
    };
    configurations {
        default = "redstone";
        redstone { kernel = "kernel"; ramdisk = "initramfs"; fdt = "fdt"; };
    };
};
ITS

"$MK" -f combined-612.its 510-with-612.itb 2>&1 | tail -3
ls -la 510-with-612.itb
