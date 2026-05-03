#!/bin/bash
# Build OpenWrt 22.03 (kernel 5.10) for mpc85xx p2020.
set -eu
OWRT=/mnt/nvme/openwrt-2203
cd "$OWRT"

./scripts/feeds update -a 2>&1 | tail -3
./scripts/feeds install -a 2>&1 | tail -3

# Use our existing baseline.config (24.10/master compat — should mostly work
# in 22.03 too; defconfig will normalize)
cp -f /mnt/nvme/redstone-build/scripts/baseline.config .config
yes "" | make defconfig 2>&1 | tail -5

grep -E "TARGET_mpc85xx|TARGET_ROOTFS_INITRAMFS" .config | head -8

# Patch p2020.mk for no-gzip (vendor U-Boot known gunzip bug)
P=$OWRT/target/linux/mpc85xx/image/p2020.mk
if grep -q "kernel-bin | gzip" "$P"; then
    sed -i 's#kernel-bin | gzip |#kernel-bin |#' "$P"
    sed -i 's#fit gzip#fit none#' "$P"
fi

export FORCE_UNSAFE_CONFIGURE=1
rm -rf tmp

echo "==> downloading"
make FORCE_UNSAFE_CONFIGURE=1 download -j8 2>&1 | tail -5

echo "==> building"
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) 2>&1 | tail -30

echo
echo "=== output ==="
ls -la bin/targets/mpc85xx/p2020/ 2>&1
