#!/bin/bash
echo "=== root node children ==="
dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb 2>/dev/null | grep -E "^\t[a-z0-9@]+ \{" | head -10

echo
echo "=== chosen actual content ==="
dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb 2>/dev/null | sed -n '/chosen {/,/};/p' | head -10

echo
echo "=== aliases serial0 actual path ==="
dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb 2>/dev/null | grep "serial0" | head -3
