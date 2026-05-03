#!/bin/bash
# Fix mpc85xx 6.6 vmlinux size by reducing CONFIG_DATA_SHIFT from 24 (16MB)
# to 12 (4KB), eliminating the 7MB zero-padding gap before .init.text.
# Without this, raw vmlinux >= 16MB and won't fit vendor U-Boot's dtb-alloc
# constraint (0-16MB region).
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

cd "$KSRC"

# Force DATA_SHIFT to PAGE_SHIFT (12 = 4KB align)
./scripts/config --set-val DATA_SHIFT 12 \
                 --enable DATA_SHIFT_BOOL \
                 --disable STRICT_KERNEL_RWX \
                 --disable STRICT_MODULE_RWX

# Verify
grep -E "CONFIG_DATA_SHIFT|CONFIG_STRICT_KERNEL_RWX" .config | head -5

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

yes "" | make olddefconfig 2>&1 | tail -3
grep -E "CONFIG_DATA_SHIFT|CONFIG_STRICT_KERNEL_RWX" .config | head -5

# Rebuild
rm -f vmlinux
make -j$(nproc) vmlinux 2>&1 | tail -5

# Show new section layout + raw bin size
ls -la vmlinux
"$TC/bin/powerpc-openwrt-linux-musl-objdump" -h vmlinux | grep -E "init.text|\.text\\b" | head -3
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary vmlinux /tmp/vmlinux-trimmed.bin
ls -la /tmp/vmlinux-trimmed.bin
