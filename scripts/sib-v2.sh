#!/bin/bash
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

export PATH="$TC/bin:/mnt/nvme/immortalwrt/staging_dir/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

cd "$KSRC"

# Drop our verified dtb's source into the dts dir.
# The boot Makefile auto-discovers dts → dtb → simpleImage.<dt>.
# Need a .dts file (not just .dtb) so the rule can compile it.
/mnt/nvme/immortalwrt/staging_dir/host/bin/dtc -I dtb -O dts \
    /tmp/redstone-stage1.dtb -o arch/powerpc/boot/dts/redstone-stage1.dts 2>&1 | head -5

# Patch boot/Makefile so simpleImage.redstone-stage1 is in image-y
# (idempotent — only add if not already there)
if ! grep -q "image-y.*simpleImage.redstone-stage1" arch/powerpc/boot/Makefile; then
    # Add right after the ws-ap3825i image line so it lives next to other simpleImage entries.
    sed -i '/image-\$(CONFIG_WS_AP3825I)/a image-y += simpleImage.redstone-stage1' arch/powerpc/boot/Makefile
fi

# Also need src-plat-y to include simpleboot.c + fixed-head.S so they get built.
if ! grep -q "src-plat-y.*simpleboot.c" arch/powerpc/boot/Makefile; then
    sed -i '/src-plat-\$(CONFIG_WS_AP3825I)/a src-plat-y += simpleboot.c fixed-head.S' arch/powerpc/boot/Makefile
fi

# wrapper script already has a `simpleboot-*)` glob fallback that matches
# our `simpleboot-redstone-stage1` — no patch needed. Undo any prior bad insert.
sed -i '/^[[:space:]]*simpleboot-redstone-stage1)$/d' arch/powerpc/boot/wrapper

grep -nE "simpleImage.redstone|simpleboot.c|simpleboot-redstone" arch/powerpc/boot/Makefile arch/powerpc/boot/wrapper | head -10

# Try the build
echo "=== building simpleImage.redstone-stage1 ==="
make -j$(nproc) simpleImage.redstone-stage1 2>&1 | tail -25

ls -la arch/powerpc/boot/simpleImage.redstone-stage1 2>&1
file arch/powerpc/boot/simpleImage.redstone-stage1 2>&1 || true
