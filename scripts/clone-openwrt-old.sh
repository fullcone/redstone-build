#!/bin/bash
set -ex
cd /mnt/nvme

# OpenWrt 22.03 = kernel 5.10 (matches EdgeNOS)
if [ ! -d openwrt-2203 ]; then
    git clone --depth 1 --branch openwrt-22.03 https://git.openwrt.org/openwrt/openwrt.git openwrt-2203
fi
echo "=== 22.03 kernel ver ==="
grep KERNEL_PATCHVER /mnt/nvme/openwrt-2203/target/linux/mpc85xx/Makefile

# OpenWrt 23.05 = kernel 5.15
if [ ! -d openwrt-2305 ]; then
    git clone --depth 1 --branch openwrt-23.05 https://git.openwrt.org/openwrt/openwrt.git openwrt-2305
fi
echo "=== 23.05 kernel ver ==="
grep KERNEL_PATCHVER /mnt/nvme/openwrt-2305/target/linux/mpc85xx/Makefile
