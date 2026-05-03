#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

echo "=== zImage.elf sections ==="
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -S \
    "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1.elf" 2>&1 | grep -E "Name|dtb|wrapper|kernel" | head -10

echo
echo "=== simpleImage.elf program headers ==="
"$TC/bin/powerpc-openwrt-linux-musl-readelf" -l \
    "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1.elf" 2>&1 | head -25

echo
echo "=== verify _dtb_start symbol position ==="
"$TC/bin/powerpc-openwrt-linux-musl-nm" \
    "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1.elf" 2>&1 | grep -E "_dtb_start|_dtb_end|_start" | head -10

echo
echo "=== simpleImage.elf -> raw binary diff ==="
ls -la "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" \
       "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1.elf" 2>&1
