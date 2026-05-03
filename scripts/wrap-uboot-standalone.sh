#!/bin/bash
set -ex
MK=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
SRC=/mnt/nvme/uboot-mainline/u-boot/u-boot.bin
OUT=/mnt/nvme/uboot-mainline/u-boot/u-boot-chain.uimg

"$MK" -A ppc -O u-boot -T standalone -C none -a 0x01000000 -e 0x01000000 \
    -n "mainline u-boot 2024.10 chainload" -d "$SRC" "$OUT"

ls -la "$OUT"
"$MK" -l "$OUT"
