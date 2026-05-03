#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

export PATH="$TC/bin:/mnt/nvme/immortalwrt/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

cd "$KSRC"

cp -f .config .config.before-disable-hardening

# Disable 5.16+/6.x hardening that doubles vmlinux size and may break early
# boot on vendor U-Boot. EdgeNOS 5.10 didn't have these.
./scripts/config \
    --disable STRICT_KERNEL_RWX \
    --disable STRICT_MODULE_RWX \
    --disable VMAP_STACK \
    --disable PPC_KUEP \
    --disable PPC_KUAP \
    --disable RANDOMIZE_KSTACK_OFFSET \
    --disable RANDOMIZE_KSTACK_OFFSET_DEFAULT

yes "" | make olddefconfig 2>&1 | tail -3

echo "=== verify disabled ==="
grep -E "STRICT_KERNEL_RWX|VMAP_STACK|PPC_KUAP|PPC_KUEP|RANDOMIZE_KSTACK" .config | head -10

echo "=== rebuild vmlinux + boot images ==="
make -j$(nproc) vmlinux 2>&1 | tail -5
ls -la vmlinux
echo "=== vmlinux size ==="
"$TC/bin/powerpc-openwrt-linux-musl-size" vmlinux
