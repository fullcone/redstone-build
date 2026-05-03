#!/bin/bash
# Apply Redstone P3 customizations to the OpenWrt 22.03 build tree.
#
# Called from build-prod-base.sh Stage 2 (before initramfs build).
# Idempotent — safe to re-run.
#
# Inputs:
#   $REDSTONE/config/p3-switch.config    package list (CONFIG_PACKAGE_*=y)
#   $REDSTONE/files/                     static files (rooted at /, copied as-is)
#
# Output:
#   Modifies $OPENWRT/.config (appends p3-switch.config)
#   Copies $REDSTONE/files/ → $OPENWRT/files/  (OpenWrt's "extra files" hook)

set -eo pipefail

REDSTONE=${REDSTONE:-/mnt/nvme/redstone-build}
OPENWRT=${OPENWRT:-/mnt/nvme/openwrt-2203}

CFG=$REDSTONE/config/p3-switch.config
FILES=$REDSTONE/files
DST_CFG=$OPENWRT/.config
DST_FILES=$OPENWRT/files

[ -f "$CFG" ]   || { echo "diy-script: missing $CFG"; exit 1; }
[ -d "$FILES" ] || { echo "diy-script: missing $FILES"; exit 1; }
[ -f "$DST_CFG" ] || { echo "diy-script: $DST_CFG not present — run 'make defconfig' first"; exit 1; }

# 1. Merge package config — drop existing P3 lines, append fresh
sed -i '/# --- BEGIN P3-SWITCH ---/,/# --- END P3-SWITCH ---/d' "$DST_CFG"
{
    echo
    echo "# --- BEGIN P3-SWITCH ---  (added by redstone-build/scripts/diy-script.sh)"
    cat "$CFG"
    echo "# --- END P3-SWITCH ---"
} >> "$DST_CFG"

# Re-resolve dependencies (turns =y into transitive =y/=m as needed).
# Use a here-file of newlines instead of `yes "" | ...` so we don't have
# a pipe at all (avoids SIGPIPE-141 from yes that would trip pipefail and
# also prevents the make exit code from being masked by tail).
DEFCONFIG_LOG=$(mktemp -t diy-defconfig-XXXXXX.log)
yes "" | head -n 200 > /tmp/diy-yes.txt
if ! ( cd "$OPENWRT" && make defconfig < /tmp/diy-yes.txt > "$DEFCONFIG_LOG" 2>&1 ); then
    echo "FAIL: make defconfig" >&2
    tail -50 "$DEFCONFIG_LOG" >&2
    rm -f /tmp/diy-yes.txt "$DEFCONFIG_LOG"
    exit 1
fi
tail -3 "$DEFCONFIG_LOG"
rm -f /tmp/diy-yes.txt "$DEFCONFIG_LOG"

# 2. Copy static files — OpenWrt's "files/" overlay convention
mkdir -p "$DST_FILES"
cp -a "$FILES/." "$DST_FILES/"

# 2a. Make uci-defaults executable (required by procd)
find "$DST_FILES/etc/uci-defaults" -type f -exec chmod +x {} \;
# 2b. Make /usr/local/bin scripts executable
find "$DST_FILES/usr/local/bin" -type f -exec chmod +x {} \;

# 3. Sanity: count enabled P3 packages
P3_COUNT=$(grep -c '^CONFIG_PACKAGE.*=y' "$CFG")
TOTAL_Y=$(grep -c '^CONFIG_PACKAGE.*=y' "$DST_CFG")
echo "diy-script: applied $P3_COUNT P3 packages (total =y now: $TOTAL_Y)"
echo "diy-script: copied $(find "$FILES" -type f | wc -l) static files into $DST_FILES"
