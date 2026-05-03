#!/bin/sh
# Build cuImage.redstone-stage1 — PowerPC self-contained kernel image with
# embedded DTB and boot wrapper. vendor U-Boot won't touch the FDT (no
# ft_fixup_l2cache pass), since the kernel boot wrapper handles it.

set -eu

KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
DTB=/tmp/redstone-stage1.dtb

cd "$KSRC"
cp "$DTB" arch/powerpc/boot/dts/redstone-stage1.dtb

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

make -j"$(nproc)" simpleImage.redstone-stage1 2>&1 | tail -15

ls -la arch/powerpc/boot/simpleImage.redstone-stage1 2>&1
file arch/powerpc/boot/simpleImage.redstone-stage1 2>&1
xxd arch/powerpc/boot/simpleImage.redstone-stage1 | head -2
