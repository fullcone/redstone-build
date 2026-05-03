#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
cd "$KSRC"

echo "=== soc node ranges in our padded dtb ==="
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb 2>/dev/null | sed -n '/soc@ffe00000 {/,/^[\t ]\+device-type/p' | head -30

echo
echo "=== full dtb root node ==="
dtc -I dtb -O dts /tmp/dtb-diff/clean-dtb-1.dtb 2>/dev/null | head -20

echo
echo "=== mainline arch/powerpc/boot/serial.c console probe ==="
grep -nE "stdout|find_node|ns16550_console_init" arch/powerpc/boot/serial.c | head -10
