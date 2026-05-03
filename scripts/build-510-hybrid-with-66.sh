#!/bin/bash
# Build 5.10 hybrid FIT with 6.6 vmlinux + dtb + initramfs embedded as
# /opt/* files inside 5.10 initramfs. kexec from inside 5.10 can find them
# without network (avoids BCM54616S TX-stall issue).
set -eu

OUT=/mnt/nvme/immortalwrt/redstone-fit
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

# 1. Make a small cpio with /opt/vmlinux-66 + dtb + initramfs + /usr/sbin/kexec
rm -rf stage
mkdir -p stage/opt stage/usr/sbin
# kexec wants ELF, not raw bin (cannot determine file type for raw)
cp -f /mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135/vmlinux stage/opt/vmlinux-66
cp -f dtb66.dtb                                                         stage/opt/dtb-66
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio stage/opt/initramfs-66
# Inject kexec binary + libz.so.1 (kexec dynamic dep)
# Use kexec-tools 2.0.32 (newer, fixes 2.0.21 PPC32 ELF parser segfault)
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/build/sbin/kexec stage/usr/sbin/kexec
chmod +x stage/usr/sbin/kexec
mkdir -p stage/usr/lib
# Find libz.so.1 in staging
LIBZ=$(find /mnt/nvme/openwrt-2203/staging_dir/target-powerpc_8540_musl -name "libz.so*" 2>/dev/null | head -3)
echo "Found libz: $LIBZ"
for f in $LIBZ; do cp -af "$f" stage/usr/lib/ ; done
ls -la stage/usr/lib/
cd stage
find . | cpio -o -H newc > ../extra-66.cpio 2>/dev/null
cd ..
ls -la extra-66.cpio

# 2. Concatenate: 5.10 base initramfs + extra cpio with 6.6 files
cat /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio extra-66.cpio > combined-initramfs.cpio
ls -la combined-initramfs.cpio

# 3. Build FIT with EdgeNOS 5.10 kernel + combined initramfs + padded dtb
# Use our rebuilt EdgeNOS 5.10 kernel WITH CONFIG_KEXEC=y
cp -f /tmp/edgenos-510-kexec.bin ek510.bin
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb -o /tmp/c.dts 2>/dev/null
dtc -I dts -O dtb -p 0x1000 /tmp/c.dts -o edtb-510.dtb 2>/dev/null

cat > combined.its <<'ITS'
/dts-v1/;
/ {
    description = "5.10 hybrid + 6.6 files in /opt for kexec";
    #address-cells = <0x01>;
    images {
        kernel { description = "EdgeNOS 5.10 kernel"; data = /incbin/("ek510.bin");
            type = "kernel"; arch = "ppc"; os = "linux"; compression = "none";
            load = <0x00>; entry = <0x00>; };
        initramfs { description = "OpenWrt 5.10 initramfs + /opt 6.6 files";
            data = /incbin/("combined-initramfs.cpio");
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

"$MK" -f combined.its 510-with-66.itb 2>&1 | tail -3
ls -la 510-with-66.itb
