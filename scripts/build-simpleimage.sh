#!/bin/bash
# Build a PowerPC simpleImage wrapper for redstone-stage1.
# OpenWrt boot Makefile only registers simpleboot.o + fixed-head.o for boards
# in the image-$(CONFIG_X) list (HIVEAP_330, TL_WDR4900_V1, WS_AP3825I, etc.),
# so a vanilla `make simpleImage.redstone-stage1` fails with missing .o.
# Workaround: piggyback on an existing registered board by symlink — its deps
# are already registered, so simpleboot.o + fixed-head.o get built; we then
# rerun the wrap step with our own dtb.

set -eu

KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
DTB=/tmp/redstone-stage1.dtb

cd "$KSRC"

# 1. Drop our verified dtb into the dts dir under a name that already maps
#    through the wrapper script's `simpleboot-*)` glob case.
#    Prefer hiveap-330 since it's a generic mpc85xx case.
cp -f "$DTB" arch/powerpc/boot/dts/redstone-stage1.dtb
# convert verified dtb back to dts so dtc can recompile it as part of the
# kernel build (kbuild's image rule wants a .dts target).
"$TC/bin/../../host/bin/dtc" -I dtb -O dts arch/powerpc/boot/dts/redstone-stage1.dtb \
    -o arch/powerpc/boot/dts/redstone-stage1.dts 2>/dev/null

# 2. First force-build simpleImage.hiveap-330 — that pulls simpleboot.o +
#    fixed-head.o + wrapper.a deps into the .build cache.
export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

echo "=== priming wrapper deps via hiveap-330 ==="
make -j"$(nproc)" arch/powerpc/boot/simpleboot.o arch/powerpc/boot/fixed-head.o \
                  arch/powerpc/boot/wrapper.a 2>&1 | tail -5 || true

ls -la arch/powerpc/boot/simpleboot.o arch/powerpc/boot/fixed-head.o arch/powerpc/boot/wrapper.a 2>&1 | head -5

# 3. Now manually run the wrapper script for redstone-stage1 — same recipe as
#    arch/powerpc/Makefile uses internally, but bypassing image-y registration.
echo
echo "=== wrap kernel + redstone dtb into simpleImage ==="
KOBJ=arch/powerpc/boot
# Compile our dts to dtb (kernel's host dtc, MUST live next to wrapper)
"$KOBJ/dtc" -I dts -O dtb "$KOBJ/dts/redstone-stage1.dts" -o "$KOBJ/redstone-stage1.dtb" 2>/dev/null \
    || cp -f "$DTB" "$KOBJ/redstone-stage1.dtb"

# wrapper script accepts: -p platform -i initrd -d dtb -o outfile vmlinux
$KOBJ/wrapper -p simpleboot-hiveap-330 \
              -d $KOBJ/redstone-stage1.dtb \
              -o $KOBJ/simpleImage.redstone-stage1 \
              vmlinux 2>&1 | tail -15

ls -la $KOBJ/simpleImage.redstone-stage1 2>&1
file $KOBJ/simpleImage.redstone-stage1 2>&1
xxd $KOBJ/simpleImage.redstone-stage1 | head -2
