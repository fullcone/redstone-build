#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
echo "=== simpleImage size + first dtb magic location ==="
ls -la "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1"
xxd "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" | grep -m 5 "d00d feed"

echo
echo "=== last 256 bytes of simpleImage (expect dtb append) ==="
xxd "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" | tail -16

echo
echo "=== run wrapper script in dry-run / verbose ==="
echo "Script command line was:"
ls -la "$KSRC/arch/powerpc/boot/redstone-stage1.dtb" 2>&1
echo
"$KSRC/arch/powerpc/boot/wrapper" --help 2>&1 | head -20
