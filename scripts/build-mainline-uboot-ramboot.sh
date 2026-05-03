#!/bin/bash
# Build mainline U-Boot v2024.10 P2020RDB defconfig but patched to link at
# RAM address 0x10000000 instead of NOR 0xeff80000. This allows chainloading
# from vendor U-Boot via tftp + go without touching NOR flash (zero brick risk).
set -ex
WORK=/mnt/nvme/uboot-mainline
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
mkdir -p "$WORK"
cd "$WORK"

if [ ! -d u-boot ]; then
    git clone --depth 1 --branch v2024.10 https://github.com/u-boot/u-boot.git
fi

cd u-boot

export PATH="$TC/bin:$PATH"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

# Show available P2020RDB configs
ls configs/ | grep -iE "p2020rdb" 2>/dev/null

# NAND_defconfig: main U-Boot is designed to run from RAM. Default TEXT_BASE
# is 0x11000000 (272MB) which is OUTSIDE vendor U-Boot's TLB1 linear mapping
# (typically 0-256MB only on P2020) — causes silent ITLB miss on go.
# Override to 0x02000000 (32MB, vendor's $loadaddr, well within TLB cover).
CONFIG=P2020RDB-PC_NAND_defconfig
echo "Using defconfig: $CONFIG"

make distclean
make "$CONFIG"

# Override TEXT_BASE to 0x03000000 (just under 256MB) — inside vendor U-Boot
# TLB1 (assuming standard 0..256MB linear). R_PPC_ADDR16 relocs in start.S
# don't tolerate big TEXT_BASE shift so we keep close to NAND default 0x11000000.
sed -i 's/^CONFIG_TEXT_BASE=.*/CONFIG_TEXT_BASE=0x03000000/' .config
sed -i 's/^CONFIG_SYS_TEXT_BASE=.*/CONFIG_SYS_TEXT_BASE=0x03000000/' .config
sed -i 's/^CONFIG_SYS_MONITOR_BASE=.*/CONFIG_SYS_MONITOR_BASE=0x03000000/' .config
grep -E "CONFIG_TEXT_BASE|CONFIG_SYS_TEXT_BASE" .config

make -j$(nproc) 2>&1 | tail -10

ls -la u-boot.bin u-boot 2>&1 | head -5
file u-boot.bin u-boot 2>&1 | head -3
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -h u-boot 2>&1 | grep "Entry\|Type"
