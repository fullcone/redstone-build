#!/bin/bash
# Set up OpenWrt master build for our P2020 baseline.
# Reuse same baseline.config + build.sh patches (no-gzip + dts cpu).
set -ex

OWRT=/mnt/nvme/openwrt-master/openwrt
WORK=/mnt/nvme/redstone-build
cd "$OWRT"

echo "=== feeds update + install ==="
./scripts/feeds update -a 2>&1 | tail -5
./scripts/feeds install -a 2>&1 | tail -5

echo "=== copy baseline.config to .config ==="
cp -f "$WORK/scripts/baseline.config" .config

echo "=== make defconfig ==="
make defconfig 2>&1 | tail -5

echo "=== verify mpc85xx p2020 selected ==="
grep -E "TARGET_mpc85xx|TARGET_ROOTFS_INITRAMFS" .config | head -10

echo "=== kernel patchver for mpc85xx ==="
grep KERNEL_PATCHVER target/linux/mpc85xx/Makefile

echo "=== ready. To build: cd $OWRT && make -j\$(nproc) target/linux/compile V=s"
