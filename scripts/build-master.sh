#!/bin/bash
# Build OpenWrt master (kernel 6.12) for mpc85xx p2020 with our patches.
set -eu

OWRT=/mnt/nvme/openwrt-master/openwrt
WORK=/mnt/nvme/redstone-build
cd "$OWRT"

export FORCE_UNSAFE_CONFIGURE=1
export FAKED_MODE=unknown-is-root
MAKE_VARS="FORCE_UNSAFE_CONFIGURE=1"

# Apply same p2020.mk patch (no gzip + load addr 0)
P=$OWRT/target/linux/mpc85xx/image/p2020.mk
if grep -q "kernel-bin | gzip" "$P"; then
    sed -i 's#kernel-bin | gzip |#kernel-bin |#' "$P"
    sed -i 's#fit gzip#fit none#' "$P"
fi
# Set KERNEL_LOADADDR/ENTRY=0 (matches mainline e500v2 link addr phys 0)
if ! grep -q "^  KERNEL_LOADADDR := 0x00000000" "$P"; then
    sed -i 's/^  KERNEL_LOADADDR := .*/  KERNEL_LOADADDR := 0x00000000/' "$P"
    sed -i 's/^  KERNEL_ENTRY := .*/  KERNEL_ENTRY := 0x00000000/' "$P"
    grep -E "KERNEL_LOADADDR|KERNEL_ENTRY" "$P" | head -3
fi

# Drop stale tmp/
rm -rf tmp

echo "==> downloading sources"
make $MAKE_VARS download -j8 2>&1 | tail -5

echo "==> building (parallel: $(nproc), tail -50)"
make $MAKE_VARS -j$(nproc) 2>&1 | tail -50

echo
echo "==> output:"
find bin/targets/mpc85xx/ -name "*.itb" -o -name "*kernel.bin" 2>/dev/null
ls -la bin/targets/mpc85xx/p2020/ 2>/dev/null | head -10
