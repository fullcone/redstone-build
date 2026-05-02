#!/bin/sh
# Pull the most recent build image back from the remote builder for TFTP.
# Usage: ./scripts/fetch-image.sh [BOARD]
#   BOARD defaults to 'mpc85xx/p2020' subtarget; pass an explicit prefix to
#   filter (e.g. 'freescale_p2020rdb' or 'edgecore_redstone').
#
# Output:
#   images/<basename>.itb     -- copied locally for `tftpd` ingestion
#   images/<basename>.dir/    -- the rest of the same build (kernel/dtb/etc.)
#
# Assumes ssh/key auth to root@172.16.0.143 already works.

set -eu

REMOTE=root@172.16.0.143
REMOTE_BIN=/mnt/nvme/immortalwrt/bin/targets/mpc85xx
LOCAL_DIR="$(dirname "$0")/../images"
FILTER="${1:-freescale_p2020rdb}"

mkdir -p "$LOCAL_DIR"

echo "==> remote bin/targets:"
ssh "$REMOTE" "find $REMOTE_BIN -type f \( -name '*.itb' -o -name '*.bin' -o -name '*.dtb' -o -name '*-Image*' \) | grep -E '$FILTER' | head -20"

echo
echo "==> pulling .itb files matching '$FILTER'"
ssh "$REMOTE" "find $REMOTE_BIN -name '*.itb' | grep -E '$FILTER'" \
    | while read -r f; do
        echo "  $f"
        scp "$REMOTE:$f" "$LOCAL_DIR/"
    done

echo
echo "==> local cache:"
ls -la "$LOCAL_DIR/"

echo
echo "==> next step: copy the .itb to your TFTP server, then in U-Boot:"
echo "     tftp 0x02000000 <basename>.itb"
echo "     bootm 0x02000000"
echo "   (see docs/uboot-tftp-boot.md for full env setup)"
