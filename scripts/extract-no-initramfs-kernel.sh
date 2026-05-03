#!/bin/sh
# Goal: produce a raw kernel binary WITHOUT embedded initramfs from the
# already-built OpenWrt vmlinux. Then build a clean FIT (kernel+ramdisk+fdt
# separate, EdgeNOS .its style) so the kernel image is small enough that
# vendor U-Boot can place the FDT in low memory (<16MB) for ft_fixup_l2cache.

set -eu

KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
OBJDUMP=$TC/bin/powerpc-openwrt-linux-musl-objdump
OBJCOPY=$TC/bin/powerpc-openwrt-linux-musl-objcopy

echo === vmlinux sections (initramfs related) ===
"$OBJDUMP" -h "$KSRC/vmlinux" 2>&1 | grep -E "initramfs|init.ramfs|Idx Name|^[[:space:]]+[0-9]+ \." | head -30

echo
echo === full section list ===
"$OBJDUMP" -h "$KSRC/vmlinux" 2>&1 | head -50
