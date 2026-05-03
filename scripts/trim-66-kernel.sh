#!/bin/bash
# Trim 6.6 kernel by using EdgeNOS minimal as5610_defconfig as base.
# Goal: get vmlinux raw < 14MB so vendor U-Boot can fit dtb in 0-16MB.
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
EDGE=/mnt/c/other_project/R0678/redstone_system_extracted/_external/edgenos/config/kernel/as5610_defconfig

cd "$KSRC"
cp -f .config .config.bak.before-trim

# Copy EdgeNOS minimal config + add things needed for OpenWrt initramfs
cp -f /tmp/edgenos-as5610_defconfig .config

# Add OpenWrt-required basics (initramfs source pointing to our cpio)
cat >> .config <<'CFG'
# OpenWrt initramfs path (pre-built)
CONFIG_INITRAMFS_SOURCE=""
CONFIG_INITRAMFS_FORCE=n
CONFIG_BLK_DEV_RAM=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_RD_GZIP=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_TMPFS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
# 5.10→6.6 MTD split: disable MTD_BLOCK (causes link error in 6.6 with this config)
CFG

# OpenWrt generic hack patch 402 calls register_mtd_blktrans_devs from mtdcore,
# which requires MTD_BLKDEVS (selected by MTD_BLOCK). Keep MTD_BLOCK enabled
# despite minor size cost — it's the only way to satisfy OpenWrt's patch.
./scripts/config --enable MTD_BLOCK \
                 --enable MTD_BLKDEVS
cat >> .config <<'CFG'
# Re-enable disabled hardening that was off for 6.6 testing (defaults)
CFG

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

# olddefconfig fills in dependencies
yes "" | make olddefconfig 2>&1 | tail -3

# Build vmlinux only (skip wrapper for fast turnaround)
rm -f vmlinux
make -j$(nproc) vmlinux 2>&1 | tail -5

# Check size
ls -la vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-size" vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary vmlinux /tmp/vmlinux-trimmed.bin
ls -la /tmp/vmlinux-trimmed.bin
