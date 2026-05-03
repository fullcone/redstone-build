#!/bin/sh
# Patch p2020si-pre.dtsi to:
#   1. rename `PowerPC,P2020@0` → `cpu@0`
#   2. add `cpu@1` (P2020 is dual-core; mainline DTS only declares core 0
#      because most P2020RDB boards used a single-core-only U-Boot variant)
# Reason: Redstone vendor U-Boot's ft_fixup_l2cache iterates all cpu nodes
# expecting `cpu@N` naming and BOTH cores present. Without these the fixup
# returns FDT_ERR_NOTFOUND mid-iteration and the boot stalls.
# Idempotent.

set -eu

DTSI=$(find /mnt/nvme/immortalwrt/build_dir -name p2020si-pre.dtsi 2>/dev/null \
            -path "*linux-mpc85xx_p2020*" | head -1)

if [ -z "$DTSI" ] || [ ! -f "$DTSI" ]; then
    echo "ERROR: p2020si-pre.dtsi not found (kernel not built yet?)" >&2
    exit 1
fi

if grep -q "cpu@1 {" "$DTSI"; then
    echo "already patched"
    exit 0
fi

# Backup first
cp "$DTSI" "$DTSI.orig"

# Use awk to rewrite the cpus { ... } block
awk '
BEGIN { in_cpus=0; depth=0; printed=0 }
{
    if (in_cpus) {
        # Track brace depth inside cpus block
        for (i=1; i<=length($0); i++) {
            c = substr($0, i, 1)
            if (c == "{") depth++
            if (c == "}") depth--
        }
        if (depth == 0) {
            # Closing the cpus block — emit our replacement before the }
            if (!printed) {
                print "\t\tcpu@0 {"
                print "\t\t\tdevice_type = \"cpu\";"
                print "\t\t\treg = <0x0>;"
                print "\t\t\tnext-level-cache = <&L2>;"
                print "\t\t\tcompatible = \"PowerPC,P2020\";"
                print "\t\t};"
                print ""
                print "\t\tcpu@1 {"
                print "\t\t\tdevice_type = \"cpu\";"
                print "\t\t\treg = <0x1>;"
                print "\t\t\tnext-level-cache = <&L2>;"
                print "\t\t\tcompatible = \"PowerPC,P2020\";"
                print "\t\t};"
                printed=1
            }
            print
            in_cpus=0
            next
        }
        # Skip lines inside the original cpus block (we are replacing them)
        next
    }
    if ($0 ~ /^\tcpus \{/) {
        print
        in_cpus=1
        depth=1
        next
    }
    print
}
' "$DTSI.orig" > "$DTSI"

echo "patched: rewrote cpus{} block (cpu@0 + cpu@1)"
echo "--- new cpus block ---"
sed -n '/^\tcpus {/,/^\t};/p' "$DTSI"
