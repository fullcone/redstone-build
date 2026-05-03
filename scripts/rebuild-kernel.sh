#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

cd "$KSRC"

# rebuild vmlinux only (we changed .config — head_fsl_booke.S compiled with
# new PPC_EARLY_DEBUG_16550 macros).
yes "" | make olddefconfig 2>&1 | tail -3
make -j$(nproc) vmlinux 2>&1 | tail -5
ls -la vmlinux arch/powerpc/boot/zImage 2>&1
