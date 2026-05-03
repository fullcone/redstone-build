#!/bin/bash
# Build linux-5.15.x vmlinux for kexec test (5.10 work, 6.6/6.12 silent — bisect)
set -ex
WORK=/mnt/nvme/linux-515
TC=/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
mkdir -p "$WORK"
cd "$WORK"

KVER=5.15.180
if [ ! -f linux-${KVER}.tar.xz ]; then
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-${KVER}.tar.xz" || \
    wget -q "https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.15.179.tar.xz"
    KVER=$(ls linux-5.15.*.tar.xz | sed 's/linux-//;s/.tar.xz//' | tail -1)
fi

if [ ! -d linux-${KVER} ]; then
    tar xf linux-${KVER}.tar.xz
fi

cd linux-${KVER}

# Use same .config as 5.10 EdgeNOS (closest base)
cp -f /tmp/edgenos-files/config/as5610_defconfig .config
echo "CONFIG_KEXEC=y" >> .config

# Force DATA_SHIFT=12
./scripts/config --set-val DATA_SHIFT 12 \
                 --enable DATA_SHIFT_BOOL \
                 --disable STRICT_KERNEL_RWX \
                 --disable STRICT_MODULE_RWX 2>/dev/null || true

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/openwrt-2203/staging_dir/target-powerpc_8540_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

yes "" | make olddefconfig 2>&1 | tail -3
grep -E "DATA_SHIFT|KEXEC" .config | head -5
make -j$(nproc) vmlinux 2>&1 | tail -5

ls -la vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -l vmlinux | head -10
