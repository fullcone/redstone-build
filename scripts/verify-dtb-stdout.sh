#!/bin/bash
echo "=== padded dtb chosen{} ==="
dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb 2>/dev/null | sed -n '/chosen/,/};/p' | head -10

echo
echo "=== source dts grep ==="
grep -B 1 -A 5 chosen /mnt/nvme/immortalwrt/redstone-fit/redstone.dts | head -10

echo
echo "=== full chosen block raw bytes ==="
dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb 2>/dev/null | grep -E "stdout|chosen|bootargs" | head -10
