#!/bin/sh
# Patch ImmortalWrt mpc85xx p2020.mk so the FIT kernel is NOT gzip'd.
# Reason: at 14MB compressed → ~30MB decompressed, the gunzip target
# overlaps the FIT image staging region and U-Boot reports
# "GUNZIP: uncompress, out-of-mem or overwrite error".
# Raw kernel + FIT(none) avoids the in-place decompress entirely; U-Boot
# just relocates the kernel blob to its load address.
# Idempotent.

set -eu

P=/mnt/nvme/immortalwrt/target/linux/mpc85xx/image/p2020.mk

if grep -q "kernel-bin | gzip" "$P"; then
    sed -i 's#kernel-bin | gzip |#kernel-bin |#' "$P"
    sed -i 's#fit gzip#fit none#' "$P"
    echo "patched: kernel pipeline stripped of gzip"
else
    echo "already patched"
fi

grep -A 1 "^  KERNEL :=" "$P"
