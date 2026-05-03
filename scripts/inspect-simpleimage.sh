#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

cd "$KSRC"

echo "=== simpleImage.redstone-stage1 first 32 bytes ==="
xxd arch/powerpc/boot/simpleImage.redstone-stage1 | head -2

echo
echo "=== zImage ELF entry (the elf form of the wrapper) ==="
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -h arch/powerpc/boot/zImage 2>&1 | grep -E "Entry|Magic|Type"

echo
echo "=== wrapper script defaults (link_address / entry) ==="
grep -nE "link_address=|entry_point=|entry=" arch/powerpc/boot/wrapper | head -10

echo
echo "=== zImage objcopy -O binary == simpleImage? ==="
ls -la arch/powerpc/boot/zImage arch/powerpc/boot/zImage.bin 2>/dev/null arch/powerpc/boot/simpleImage.redstone-stage1 2>&1

echo
echo "=== zImage program headers ==="
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -l arch/powerpc/boot/zImage 2>&1 | head -20
