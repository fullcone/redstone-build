#!/bin/bash
# Add CONFIG_KEXEC + kexec-tools to OpenWrt 22.03 build, plus 5.10 kernel.
# Goal: boot 5.10, then kexec to 6.6 (bypasses vendor U-Boot incompat).
set -eu
OWRT=/mnt/nvme/openwrt-2203
cd "$OWRT"

# Add kexec-tools package
echo "CONFIG_PACKAGE_kexec-tools=y" >> .config

# Enable kernel CONFIG_KEXEC for the mpc85xx kernel
KCFG=$OWRT/target/linux/mpc85xx/config-5.10
grep -E "KEXEC" "$KCFG" || true
# Force enable - append (defconfig will dedupe)
echo 'CONFIG_KEXEC=y' >> "$KCFG"
echo 'CONFIG_KEXEC_FILE=y' >> "$KCFG"

yes "" | make defconfig 2>&1 | tail -3
grep -E "kexec" .config | head -5

export FORCE_UNSAFE_CONFIGURE=1

# Rebuild only kernel + image
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) target/linux/clean
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) target/linux/compile target/linux/install package/kexec-tools/{download,compile,install} 2>&1 | tail -15

ls -la bin/targets/mpc85xx/p2020/
