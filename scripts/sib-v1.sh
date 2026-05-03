#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

export PATH="$TC/bin:/mnt/nvme/immortalwrt/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

cd "$KSRC"

rm -f arch/powerpc/boot/simpleboot.o
make V=1 arch/powerpc/boot/simpleboot.o 2>&1 | tail -25
