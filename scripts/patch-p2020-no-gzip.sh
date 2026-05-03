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
    echo "already patched (gzip)"
fi

# p2020.mk lacks KERNEL_LOADADDR; default 0x0 conflicts with P2020 reset vector
# (boot stalls after ft_fixup_l2cache because kernel can't run from 0x0 on this
# vendor U-Boot). Set 0x4000000 (64MB), well clear of low memory.
if ! grep -q "KERNEL_LOADADDR" "$P"; then
    awk '
        /^define Device\/freescale_p2020rdb/ { in_dev=1 }
        in_dev && /^  BLOCKSIZE/ {
            print "  KERNEL_LOADADDR := 0x04000000"
            print "  KERNEL_ENTRY := 0x04000000"
        }
        /^endef/ { in_dev=0 }
        { print }
    ' "$P" > "$P.tmp" && mv "$P.tmp" "$P"
    echo "patched: KERNEL_LOADADDR = 0x04000000"
else
    echo "already patched (loadaddr)"
fi

grep -A 1 "^  KERNEL :=" "$P"
