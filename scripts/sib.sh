#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

cp -f /tmp/redstone-stage1.dtb "$KSRC/arch/powerpc/boot/redstone-stage1.dtb"
export PATH="$TC/bin:/mnt/nvme/immortalwrt/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc
# OpenWrt's gcc wrapper requires STAGING_DIR (sysroot for headers like stddef.h).
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl

cd "$KSRC"

make -j$(nproc) arch/powerpc/boot/simpleboot.o arch/powerpc/boot/fixed-head.o arch/powerpc/boot/wrapper.a 2>&1 | tail -10

ls -la arch/powerpc/boot/simpleboot.o arch/powerpc/boot/fixed-head.o arch/powerpc/boot/wrapper.a 2>&1

# Now wrap. Use simpleboot-hiveap-330 (it's a registered platform).
arch/powerpc/boot/wrapper -p simpleboot-hiveap-330 \
    -d arch/powerpc/boot/redstone-stage1.dtb \
    -o arch/powerpc/boot/simpleImage.redstone-stage1 \
    vmlinux 2>&1 | tail -15

ls -la arch/powerpc/boot/simpleImage.redstone-stage1 2>&1
file arch/powerpc/boot/simpleImage.redstone-stage1 2>&1
