#!/bin/bash
set -eu

# 1. The kernel-bin used by p2020.mk: where is it staged in KDIR
KDIR=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020
ls -la "$KDIR"/zImage* "$KDIR"/vmlinux* "$KDIR"/openwrt* 2>&1 | head -30

# 2. Look at OpenWrt's image.mk macro that defines `kernel-bin`
echo
echo === image.mk kernel-bin definition ===
grep -B 1 -A 5 "^define Build/kernel-bin" /mnt/nvme/immortalwrt/include/image.mk 2>&1 | head -20

# 3. Show how mpc85xx target sets it up
echo
echo === mpc85xx image.mk full ===
cat /mnt/nvme/immortalwrt/target/linux/mpc85xx/image/Makefile 2>&1 | head -40
