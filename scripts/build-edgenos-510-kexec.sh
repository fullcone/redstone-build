#!/bin/bash
# Rebuild EdgeNOS 5.10.224 kernel with CONFIG_KEXEC=y for the chainload套娃.
# Uses EdgeNOS .config + 2 driver patches + OpenWrt 22.03 toolchain.
set -ex
WORK=/mnt/nvme/edgenos-510
TC=/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
mkdir -p "$WORK"
cd "$WORK"

if [ ! -f linux-5.10.224.tar.xz ]; then
    wget -q https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.224.tar.xz
fi

if [ ! -d linux-5.10.224 ]; then
    tar xf linux-5.10.224.tar.xz
fi

cd linux-5.10.224

# Apply EdgeNOS 2 patches
EDGE=/tmp/edgenos-files
for p in "$EDGE/patches"/*.patch; do
    [ -f "$p" ] || continue
    if patch -p1 --dry-run --forward < "$p" >/dev/null 2>&1; then
        patch -p1 < "$p"
        echo "applied: $(basename "$p")"
    else
        echo "skipped (already): $(basename "$p")"
    fi
done

# Copy EdgeNOS dts
cp -f "$EDGE/dts/redstone-stage1.dts" arch/powerpc/boot/dts/redstone-stage1.dts
if ! grep -q "redstone-stage1.dtb" arch/powerpc/boot/dts/Makefile; then
    echo 'dtb-$(CONFIG_PPC_85xx) += redstone-stage1.dtb' >> arch/powerpc/boot/dts/Makefile
fi

# Use EdgeNOS .config + force CONFIG_KEXEC=y
cp -f /tmp/edgenos-files/config/as5610_defconfig .config
echo "CONFIG_KEXEC=y" >> .config
echo "CONFIG_CRASH_DUMP=n" >> .config

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/openwrt-2203/staging_dir/target-powerpc_8540_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

yes "" | make olddefconfig 2>&1 | tail -3
grep -E "CONFIG_KEXEC" .config | head -3

# Build vmlinux + kernel binary
make -j$(nproc) vmlinux 2>&1 | tail -5

ls -la vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary vmlinux /tmp/edgenos-510-kexec.bin
ls -la /tmp/edgenos-510-kexec.bin
