#!/bin/bash
# Build mainline U-Boot v2024.10 for Freescale P2020RDB defconfig.
# Output: u-boot.bin (raw binary, ~600KB) + u-boot.img (legacy uImage wrapped)
# We chainload this from vendor U-Boot via tftp + go.
set -ex
WORK=/mnt/nvme/uboot-mainline
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
mkdir -p "$WORK"
cd "$WORK"

if [ ! -d u-boot ]; then
    git clone --depth 1 --branch v2024.10 https://github.com/u-boot/u-boot.git
fi

cd u-boot

# Use the toolchain we already have for OpenWrt (powerpc-openwrt-linux-musl-)
export PATH="$TC/bin:$PATH"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

# Find P2020RDB defconfig
ls configs/ | grep -iE "p2020|p2020rdb" | head -5

# Pick the right one — we want P2020RDB (or P2020RDB-PC variant matching real hw)
CONFIG=$(ls configs/ | grep -iE "^P2020RDB" | head -1)
echo "Using defconfig: $CONFIG"

make distclean
make "$CONFIG"

# Some P2020 boards have CONFIG_OF_BOARD_FIXUP that needs a specific dtb.
# Build defaults first, see what comes out.
make -j$(nproc) 2>&1 | tail -20

ls -la u-boot.bin u-boot.elf 2>&1 | head -5
file u-boot.bin u-boot.elf 2>&1 | head -3
