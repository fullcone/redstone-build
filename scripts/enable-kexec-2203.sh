#!/bin/bash
set -ex
OWRT=/mnt/nvme/openwrt-2203
cd "$OWRT"

# Append/override .config (after defconfig may strip them, but olddefconfig
# should preserve user overrides)
cat >> .config <<'CFG'
CONFIG_KERNEL_KEXEC=y
CONFIG_PACKAGE_kexec-tools=y
# CONFIG_PACKAGE_KEXEC_LZMA is not set
# CONFIG_PACKAGE_KEXEC_ZLIB is not set
CFG

yes "" | make defconfig 2>&1 | tail -3
grep -E "KEXEC|kexec-tools" .config | head -10

# Also patch target/linux config
KCFG=$OWRT/target/linux/mpc85xx/config-5.10
if ! grep -q "^CONFIG_KEXEC=y" "$KCFG"; then
    echo "CONFIG_KEXEC=y" >> "$KCFG"
    echo "CONFIG_KEXEC_FILE=y" >> "$KCFG"
fi

export FORCE_UNSAFE_CONFIGURE=1

# Rebuild kernel + image + kexec-tools
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) target/linux/clean
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) target/linux/compile package/kexec-tools/{download,prepare,compile,install} target/linux/install 2>&1 | tail -15

ls -la bin/targets/mpc85xx/p2020/openwrt-mpc85xx-p2020-freescale_p2020rdb-initramfs-kernel.bin
find build_dir -name kexec -type f -executable 2>/dev/null | head -3
