#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
echo "=== file sizes ==="
ls -la "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" "$KSRC/arch/powerpc/boot/redstone-stage1.dtb" 2>&1

echo
echo "=== grep d00dfeed in simpleImage (binary search) ==="
grep -obUaP "\xd0\x0d\xfe\xed" "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" 2>&1 | head -5

echo
echo "=== xxd last 1KB (dtb usually appended) ==="
xxd "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" | tail -64 | head -8

echo
echo "=== xxd around offset where dtb might be (mid-image) ==="
xxd -s 13653488 -l 256 "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" | head -16
