#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
cd "$KSRC"

echo "=== simpleboot.c console init flow ==="
grep -nE "console|serial|stdout|platform_init|ns16550|fdt_check|dt_fixup" arch/powerpc/boot/simpleboot.c | head -30

echo
echo "=== chosen / serial in our padded dtb (decoded) ==="
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb 2>/dev/null | sed -n '/aliases/,/};/p ; /chosen/,/};/p ; /serial@4600/,/};/p' | head -40

echo
echo "=== ns16550.c init ==="
grep -nE "platform_ops|reg|stdout|serial_console_init" arch/powerpc/boot/ns16550.c | head -10
