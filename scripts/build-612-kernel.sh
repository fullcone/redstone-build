#!/bin/bash
# Build linux-6.12.x vmlinux for kexec test, using same toolchain + .config as 6.6
set -ex
WORK=/mnt/nvme/linux-612
TC=/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
mkdir -p "$WORK"
cd "$WORK"

# Get latest 6.12.x
KVER=6.12.85
if [ ! -f linux-${KVER}.tar.xz ]; then
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KVER}.tar.xz" || \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.83.tar.xz"
    KVER=$(ls linux-6.12*.tar.xz | sed 's/linux-//;s/.tar.xz//')
    echo "Got version: $KVER"
fi

if [ ! -d linux-${KVER} ]; then
    tar xf linux-${KVER}.tar.xz
fi

cd linux-${KVER}

# Use the EXACT same trimmed .config from 6.6 build (works for boot test)
# /mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135/.config
cp -f /mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135/.config .config

# Force DATA_SHIFT=12 + disable STRICT_KERNEL_RWX (same trim as before)
./scripts/config --set-val DATA_SHIFT 12 \
                 --enable DATA_SHIFT_BOOL \
                 --disable STRICT_KERNEL_RWX \
                 --disable STRICT_MODULE_RWX

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/openwrt-2203/staging_dir/target-powerpc_8540_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

yes "" | make olddefconfig 2>&1 | tail -3

# Build
make -j$(nproc) vmlinux 2>&1 | tail -5

ls -la vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -l vmlinux | head -10
