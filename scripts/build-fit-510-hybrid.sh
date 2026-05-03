#!/bin/bash
# Hybrid: EdgeNOS 5.10.224 kernel.bin + OpenWrt 24.10 initramfs + EdgeNOS dtb.
# Tests if "5.10 kernel works on vendor U-Boot" with OpenWrt userspace.
set -eu

OUT=/mnt/nvme/immortalwrt/redstone-fit
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

cp -f /tmp/edgenos-components/kernel.bin                                                                                                                  ek510.bin
cp -f /mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio ow-initramfs.cpio
# Use padded clean-dtb-1.dtb (proven through zImage tests; 4KB padding gives
# vendor U-Boot space to setprop chosen.linux,stdout-path without 'chosen
# node create failed').
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb -o /tmp/clean.dts 2>/dev/null
dtc -I dts -O dtb -p 0x1000 /tmp/clean.dts -o edtb-510.dtb 2>/dev/null

ls -la ek510.bin ow-initramfs.cpio edtb-510.dtb

cat > redstone-510-hybrid.its <<'ITS'
/dts-v1/;
/ {
    description = "EdgeNOS 5.10.224 kernel + OpenWrt 24.10 initramfs + EdgeNOS dtb";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "EdgeNOS 5.10.224 raw kernel.bin (vendor U-Boot proven)";
            data = /incbin/("ek510.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };

        initramfs {
            description = "OpenWrt 24.10 initramfs (busybox dropbear etc)";
            data = /incbin/("ow-initramfs.cpio");
            type = "ramdisk";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
        };

        fdt {
            description = "EdgeNOS verified Redstone stage1 dtb";
            data = /incbin/("edtb-510.dtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };

    configurations {
        default = "redstone";
        redstone {
            description = "5.10 kernel + OpenWrt userspace hybrid";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt";
        };
    };
};
ITS

"$MK" -f redstone-510-hybrid.its redstone-510-hybrid.itb 2>&1 | tail -3
ls -la redstone-510-hybrid.itb
