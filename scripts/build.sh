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
make defconfig 2>&1 | tail -5

echo "==> building (parallel: $(nproc) jobs)"
make -j"$(nproc)" 2>&1 | tail -50

echo
echo "==> output:"
find bin/targets/mpc85xx/ -name "*.itb" -o -name "*.bin" | head -10
