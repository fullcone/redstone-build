#!/bin/bash
set -eu

WORK=/tmp/dtb-diff
mkdir -p "$WORK"
cd "$WORK"

# 1. Dump our redstone-stage1.dtb and the eth1phy variant
echo === stage1.dtb chosen + cpu0 + serial ===
dtc -I dtb -O dts /tmp/redstone-stage1.dtb -o stage1.dts 2>/dev/null
grep -B1 -A 10 "chosen\|stdout-path\|serial@" stage1.dts | head -40

echo
echo === stage1-eth1phy.dtb chosen + serial ===
dtc -I dtb -O dts /tmp/edgenos-components/dtb -o eth1phy.dts 2>/dev/null
grep -B1 -A 10 "chosen\|stdout-path\|serial@" eth1phy.dts | head -40

# 2. Try to extract dtb from the working uImage-b2-clean.itb so we can compare
echo
echo === extracting dtb from working uImage-b2-clean.itb ===
# OpenWrt mkimage doesn't support extracting; use python script with libfdt
# parsing instead. Quick path: scan binary for dtb magic d00dfeed and dump
# from there.
python3 - <<'PY'
import struct, sys
with open("/tmp/edgenos-components/uImage-b2-clean.itb", "rb") as f:
    data = f.read()

# FIT image is itself a fdt blob — parse to find /images/fdt/data
# Cheap: just find third occurrence of d00dfeed (skip outer FIT + maybe internal)
magic = b'\xd0\x0d\xfe\xed'
positions = []
off = 0
while True:
    p = data.find(magic, off)
    if p < 0: break
    positions.append(p)
    off = p + 4
print("d00dfeed positions in uImage-b2-clean.itb:", positions)

# The first position is the FIT image header itself.
# The second+ are embedded dtb sub-images.
for i, p in enumerate(positions):
    # FDT header: magic(4) totalsize(4)
    totalsize = struct.unpack(">I", data[p+4:p+8])[0]
    print(f"  pos {i}: offset 0x{p:x}, totalsize {totalsize}")
    if i > 0 and totalsize < 100000:
        with open(f"clean-dtb-{i}.dtb", "wb") as o:
            o.write(data[p:p+totalsize])
        print(f"    wrote clean-dtb-{i}.dtb")
PY

ls -la clean-dtb-*.dtb 2>/dev/null
for d in clean-dtb-*.dtb; do
    if [ -f "$d" ]; then
        echo === "$d" chosen + serial ===
        dtc -I dtb -O dts "$d" -o "${d%.dtb}.dts" 2>/dev/null
        grep -B1 -A 10 "chosen\|stdout-path\|serial@\|aliases" "${d%.dtb}.dts" | head -50
    fi
done
