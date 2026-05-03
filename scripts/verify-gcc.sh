#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-

cd "$KSRC"
echo "BOOTCC -print-file-name=include:"
powerpc-openwrt-linux-musl-gcc -print-file-name=include
echo
echo "BOOTCC -print-prog-name=cc1:"
powerpc-openwrt-linux-musl-gcc -print-prog-name=cc1
echo
echo "BOOTCC -v on simpleboot.c:"
powerpc-openwrt-linux-musl-gcc -nostdinc -isystem "$(powerpc-openwrt-linux-musl-gcc -print-file-name=include)" -E -x c arch/powerpc/boot/simpleboot.c -o /dev/null 2>&1 | head -20
