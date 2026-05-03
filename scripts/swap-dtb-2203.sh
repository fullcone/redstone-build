#!/bin/bash
# Take OpenWrt 22.03 initramfs-kernel.bin (FIT) + repack with EdgeNOS dtb.
set -eu

WORK=/mnt/nvme/openwrt-2203
KSRC=$WORK/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221
OUT=/mnt/nvme/immortalwrt/redstone-fit
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

# Use vmlinux directly (raw kernel, no FIT wrapper)
ls -la "$KSRC/vmlinux" 2>&1
TC=/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary "$KSRC/vmlinux" raw-510.bin
ls -la raw-510.bin

# Initramfs from OpenWrt 22.03 build
cp -f "$KSRC/usr/initramfs_data.cpio" 510-initramfs.cpio
ls -la 510-initramfs.cpio

# EdgeNOS verified dtb
cp -f /tmp/dtb-diff/clean-dtb-1.dtb 510-dtb.dtb
ls -la 510-dtb.dtb

cat > 510-edgenos-dtb.its <<'ITS'
/dts-v1/;
/ {
    description = "OpenWrt 22.03 5.10 raw kernel + initramfs + EdgeNOS dtb";
    #address-cells = <0x01>;
    images {
        kernel {
            description = "OpenWrt 22.03 5.10.221 raw vmlinux";
            data = /incbin/("raw-510.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };
        initramfs {
            description = "OpenWrt initramfs";
            data = /incbin/("510-initramfs.cpio");
            type = "ramdisk";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
        };
        fdt {
            description = "EdgeNOS verified Redstone dtb";
            data = /incbin/("510-dtb.dtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };
    configurations {
        default = "redstone";
        redstone {
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt";
        };
    };
};
ITS

"$MK" -f 510-edgenos-dtb.its 510-edgenos-dtb.itb 2>&1 | tail -3
ls -la 510-edgenos-dtb.itb
