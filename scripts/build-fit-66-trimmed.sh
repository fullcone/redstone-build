#!/bin/bash
set -eu
OUT=/mnt/nvme/immortalwrt/redstone-fit
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

cp -f /tmp/vmlinux-trimmed.bin                                                                                                                            k66.bin
# Use OpenWrt 22.03 5.10 initramfs (real busybox/dropbear, ~17MB)
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio initrd66.cpio
# Padded dtb proven to work
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb -o /tmp/c.dts 2>/dev/null
dtc -I dts -O dtb -p 0x1000 /tmp/c.dts -o dtb66.dtb 2>/dev/null

ls -la k66.bin initrd66.cpio dtb66.dtb

cat > 66-trim.its <<'ITS'
/dts-v1/;
/ {
    description = "OpenWrt 6.6 trimmed (DATA_SHIFT=12) raw vmlinux + initramfs + EdgeNOS dtb padded";
    #address-cells = <0x01>;
    images {
        kernel { description = "6.6 trim"; data = /incbin/("k66.bin");
            type = "kernel"; arch = "ppc"; os = "linux"; compression = "none";
            load = <0x00>; entry = <0x00>; };
        initramfs { description = "OpenWrt initramfs"; data = /incbin/("initrd66.cpio");
            type = "ramdisk"; arch = "ppc"; os = "linux"; compression = "none"; load = <0x00>; };
        fdt { description = "EdgeNOS clean dtb 4KB padded"; data = /incbin/("dtb66.dtb");
            type = "flat_dt"; arch = "ppc"; os = "linux"; compression = "none"; };
    };
    configurations {
        default = "redstone";
        redstone { kernel = "kernel"; ramdisk = "initramfs"; fdt = "fdt"; };
    };
};
ITS

"$MK" -f 66-trim.its 66-trim.itb 2>&1 | tail -3
ls -la 66-trim.itb
