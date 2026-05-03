#!/bin/bash
# Rebuild simpleImage.redstone-stage1 with the corrected dtb (chosen.stdout-path
# + memory.reg patched) actually embedded. Previous run produced an image
# without any dtb (no d00dfeed magic anywhere) — wrapper hits
# `fatal("Invalid device tree blob")` silently before console init.
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
HOSTBIN=/mnt/nvme/immortalwrt/staging_dir/host/bin

export PATH="$TC/bin:$HOSTBIN:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

cd "$KSRC"

# Always overwrite the dts in dts/ from the patched padded dtb, so kbuild
# recompiles it next time.
/usr/bin/dtc -I dtb -O dts /mnt/nvme/immortalwrt/redstone-fit/redstone-padded.dtb \
    -o arch/powerpc/boot/dts/redstone-stage1.dts

# Force-rebuild dtb + simpleImage. Touch the dts so it's newer than any
# cached output.
touch arch/powerpc/boot/dts/redstone-stage1.dts
rm -f arch/powerpc/boot/redstone-stage1.dtb \
      arch/powerpc/boot/simpleImage.redstone-stage1 \
      arch/powerpc/boot/dts/redstone-stage1.dtb

make -j$(nproc) simpleImage.redstone-stage1 2>&1 | tail -20

ls -la arch/powerpc/boot/simpleImage.redstone-stage1
echo "=== verify dtb is embedded (size sanity, dtb section presence) ==="
"$TC/bin/powerpc-openwrt-linux-musl-objdump" -h arch/powerpc/boot/simpleImage.redstone-stage1.elf 2>&1 | grep -E "dtb|kernel:" | head -3
