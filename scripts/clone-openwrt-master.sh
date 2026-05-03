#!/bin/bash
set -ex
WORK=/mnt/nvme/openwrt-master
mkdir -p "$WORK"
cd "$WORK"

if [ ! -d openwrt ]; then
    # Shallow clone master, latest only
    git clone --depth 1 https://github.com/openwrt/openwrt.git
fi

cd openwrt

# Verify kernel version for mpc85xx target
echo "=== mpc85xx kernel version ==="
grep -E "KERNEL_PATCHVER|KERNEL_TESTING_PATCHVER" target/linux/mpc85xx/Makefile

echo "=== Master commit ==="
git log --oneline -1

echo "=== mpc85xx patches available ==="
ls target/linux/mpc85xx/patches-*/ 2>/dev/null | head -20
