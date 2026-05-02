#!/bin/sh
# Remote-side: build a TFTP-loadable initramfs FIT image for one BOARD.
# Usage: ./scripts/build.sh redstone
#        ./scripts/build.sh as5612
# Falls back to the freescale_p2020rdb baseline if BOARD's profile is missing.

set -eu

BOARD=${1:-baseline}
NVME=/mnt/nvme
IMM=$NVME/immortalwrt
WORK=$NVME/redstone-build

cd "$IMM"

# .config: prefer board-specific, fall back to baseline
if [ -f "$WORK/boards/$BOARD/redstone.config" ]; then
    CONFIG_SRC="$WORK/boards/$BOARD/redstone.config"
elif [ -f "$WORK/scripts/baseline.config" ]; then
    CONFIG_SRC="$WORK/scripts/baseline.config"
else
    echo "ERROR: no .config seed found for board=$BOARD" >&2
    exit 1
fi

echo "==> seeding .config from $CONFIG_SRC"
cp "$CONFIG_SRC" .config

# Mirror: ImmortalWrt 24.10 ships tencent.com mirrors by default; on builders
# whose upstream is reachable directly (e.g. US-routed proxy) the default
# OpenWrt sources.openwrt.org / GNU upstream is faster. Set USE_UPSTREAM_MIRROR=1
# to override.
if [ "${USE_UPSTREAM_MIRROR:-0}" = "1" ]; then
    echo "==> reverting tencent mirror to OpenWrt upstream"
    # Remove ImmortalWrt's mirror patch effects by clearing custom URL prefix.
    sed -i '/^CONFIG_DOWNLOAD_BASE_URL/d' .config
    echo '# CONFIG_DOWNLOAD_BASE_URL is not set' >> .config
fi

make defconfig 2>&1 | tail -5

echo "==> downloading all sources first (parallel: 8 jobs)"
make download -j8 V=s 2>&1 | tail -10

echo "==> building (parallel: $(nproc) jobs, V=s for full log)"
make -j"$(nproc)" V=s 2>&1 | tail -100

echo
echo "==> output:"
find bin/targets/mpc85xx/ -name "*.itb" -o -name "*.bin" | head -10
