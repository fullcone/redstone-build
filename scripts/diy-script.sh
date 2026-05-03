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

# 0. Ensure feeds are properly indexed AND installed.
#    Bug we hit: feeds/<name>.index can be 0 bytes after a botched
#    `feeds update -i`, which makes `feeds install -a` silently do nothing
#    for that feed (most P3 packages then drop in `make defconfig`).
#    Force a re-index when any per-feed index file is empty, then install.
for f in /mnt/nvme/openwrt-2203/feeds/*.index; do
    fname=$(basename "$f" .index)
    [ "$fname" = "*" ] && continue
    if [ ! -s "$f" ]; then
        echo "diy-script: feeds index $fname is empty — regenerating"
        ( cd "$OPENWRT" && rm -rf "feeds/${fname}.tmp" "tmp/info" )
        IDX_LOG=$(mktemp -t diy-feedidx-XXXXXX.log)
        idx_rc=0
        ( cd "$OPENWRT" && ./scripts/feeds update -i "$fname" > "$IDX_LOG" 2>&1 ) || idx_rc=$?
        if [ "$idx_rc" -ne 0 ]; then
            echo "FAIL: feeds update -i $fname (rc=$idx_rc)" >&2
            tail -50 "$IDX_LOG" >&2
            rm -f "$IDX_LOG"
            exit "$idx_rc"
        fi
        rm -f "$IDX_LOG"
        [ -s "$f" ] || { echo "FAIL: $fname index still empty after re-update" >&2; exit 1; }
    fi
done

FEEDS_LOG=$(mktemp -t diy-feeds-XXXXXX.log)
feeds_rc=0
( cd "$OPENWRT" && ./scripts/feeds install -a > "$FEEDS_LOG" 2>&1 ) || feeds_rc=$?
if [ "$feeds_rc" -ne 0 ]; then
    echo "FAIL: feeds install (rc=$feeds_rc)" >&2
    tail -50 "$FEEDS_LOG" >&2
    rm -f "$FEEDS_LOG"
    exit "$feeds_rc"
fi
NEW_LINKS=$(grep -c "Installing package" "$FEEDS_LOG" 2>/dev/null || echo 0)
echo "diy-script: feeds install (new links: $NEW_LINKS)"
rm -f "$FEEDS_LOG"

# 1. Merge package config — drop existing P3 lines, append fresh
sed -i '/# --- BEGIN P3-SWITCH ---/,/# --- END P3-SWITCH ---/d' "$DST_CFG"
{
    echo
    echo "# --- BEGIN P3-SWITCH ---  (added by redstone-build/scripts/diy-script.sh)"
    cat "$CFG"
    echo "# --- END P3-SWITCH ---"
} >> "$DST_CFG"

# Re-resolve dependencies (turns =y into transitive =y/=m as needed).
# `make defconfig` is non-interactive — no stdin needed. Capture the
# output to a tempfile so we can show last 3 lines without piping into
# tail (which would mask make's exit code under set -eo pipefail).
DEFCONFIG_LOG=$(mktemp -t diy-defconfig-XXXXXX.log)
defconfig_rc=0
( cd "$OPENWRT" && make defconfig > "$DEFCONFIG_LOG" 2>&1 ) || defconfig_rc=$?
if [ "$defconfig_rc" -ne 0 ]; then
    echo "FAIL: make defconfig (rc=$defconfig_rc)" >&2
    tail -50 "$DEFCONFIG_LOG" >&2
    rm -f "$DEFCONFIG_LOG"
    exit "$defconfig_rc"
fi
tail -3 "$DEFCONFIG_LOG"
rm -f "$DEFCONFIG_LOG"

# 2. Copy static files — OpenWrt's "files/" overlay convention
mkdir -p "$DST_FILES"
cp -a "$FILES/." "$DST_FILES/"

# 2a. Make uci-defaults executable (required by procd)
find "$DST_FILES/etc/uci-defaults" -type f -exec chmod +x {} \;
# 2b. Make /usr/local/bin scripts executable
find "$DST_FILES/usr/local/bin" -type f -exec chmod +x {} \;

# 3. Sanity: verify P3 packages survived `make defconfig`. defconfig silently
#    strips entries whose Makefile isn't reachable (feed not installed, package
#    masked by target, etc.). If too many drop, fail with the missing list.
P3_REQUESTED=$(grep -E '^CONFIG_PACKAGE_[A-Za-z0-9_-]+=y' "$CFG" \
               | sed 's/=y$//' | sort -u)
P3_PRESENT=$(echo "$P3_REQUESTED" | while read sym; do
    grep -q "^${sym}=y" "$DST_CFG" && echo "$sym"
done)
P3_REQ_N=$(echo "$P3_REQUESTED" | wc -l)
P3_OK_N=$(echo "$P3_PRESENT"   | wc -l)
P3_MISSING=$(comm -23 <(echo "$P3_REQUESTED") <(echo "$P3_PRESENT"))

echo "diy-script: P3 packages requested=$P3_REQ_N survived-defconfig=$P3_OK_N"
if [ -n "$P3_MISSING" ]; then
    echo "diy-script: WARNING — these P3 entries were stripped by make defconfig:" >&2
    echo "$P3_MISSING" | sed 's/^/  /' >&2
fi
# Hard fail if MORE than 20% dropped — almost certainly a feeds/config issue
if [ "$P3_OK_N" -lt $(( P3_REQ_N * 80 / 100 )) ]; then
    echo "FAIL: only $P3_OK_N/$P3_REQ_N P3 packages survived (<80%). Check feeds." >&2
    exit 1
fi

TOTAL_Y=$(grep -c '^CONFIG_PACKAGE.*=y' "$DST_CFG")
echo "diy-script: total =y after merge: $TOTAL_Y"
echo "diy-script: copied $(find "$FILES" -type f | wc -l) static files into $DST_FILES"
