#!/bin/sh
# Remote-side: prepare ImmortalWrt build tree on /mnt/nvme/.
# - clones ImmortalWrt 24.10 if not present
# - runs feeds update + install
# - applies our patches/ if any
# Idempotent.

set -eu

NVME=/mnt/nvme
IMM_BRANCH=openwrt-24.10
IMM_TAG=v24.10.6

cd "$NVME"

if [ ! -d immortalwrt/.git ]; then
    echo "==> cloning ImmortalWrt $IMM_BRANCH"
    git clone --depth 100 --branch "$IMM_BRANCH" \
        https://github.com/immortalwrt/immortalwrt.git immortalwrt
fi

cd immortalwrt
echo "==> ImmortalWrt at $(git log --oneline -1)"

echo "==> feeds update + install"
./scripts/feeds update -a 2>&1 | tail -5
./scripts/feeds install -a 2>&1 | tail -5

echo "==> done"
