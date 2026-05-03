#!/bin/bash
# Build U-Boot v2013.01.01 with ONIE patches for AS5610-52X using OpenWrt toolchain.
set -ex
WORK=/mnt/nvme/uboot-2013
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
ONIE=/mnt/nvme/onie
mkdir -p "$WORK"
cd "$WORK"

# Download tarball
if [ ! -f u-boot-2013.01.01.tar.bz2 ]; then
    wget -q https://ftp.denx.de/pub/u-boot/u-boot-2013.01.01.tar.bz2
fi

# Extract
if [ ! -d u-boot-2013.01.01 ]; then
    tar xjf u-boot-2013.01.01.tar.bz2
fi

cd u-boot-2013.01.01

# Apply ONIE generic patches (in series order)
ONIE_PATCH=$ONIE/patches/u-boot/2013.01.01
if [ ! -f .onie_generic_applied ]; then
    while IFS= read -r p; do
        case "$p" in '#'*|'') continue;; esac
        echo "Applying generic: $p"
        patch -p1 < "$ONIE_PATCH/$p" || { echo "FAILED: $p"; exit 1; }
    done < "$ONIE_PATCH/series"
    touch .onie_generic_applied
fi

# Apply AS5610-52X patches
AS5610_PATCH=$ONIE/machine/accton/accton_as5610_52x/u-boot
if [ ! -f .as5610_applied ]; then
    while IFS= read -r p; do
        case "$p" in '#'*|'') continue;; esac
        echo "Applying as5610: $p"
        patch -p1 < "$AS5610_PATCH/$p" || { echo "FAILED: $p"; exit 1; }
    done < "$AS5610_PATCH/series"
    touch .as5610_applied
fi

export PATH="$TC/bin:$PATH"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

# Configure for AS5610-52X
make AS5610_52X_config 2>&1 | tail -3

# Build
make -j$(nproc) 2>&1 | tail -25

ls -la u-boot.bin u-boot 2>&1
file u-boot.bin u-boot 2>&1 | head -3
