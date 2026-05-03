#!/bin/bash
# Force-enable PPC_EARLY_DEBUG_FSL_UART so kernel head_fsl_booke.S can print
# via direct UART mmio writes immediately after TLB1 is set up — much earlier
# than the normal printk path. If we still see no output after this, the
# kernel is faulting before TLB setup completes.
set -ex
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

cd "$KSRC"

# Save original .config
cp -f .config .config.bak.$(date +%s) 2>/dev/null || true

# Drop conflicting choice + add early debug = FSL_UART for P2020 UART0 (CCSR+0x4500)
sed -i '/^CONFIG_PPC_EARLY_DEBUG_/d' .config
sed -i '/^# CONFIG_PPC_EARLY_DEBUG/d' .config
cat >> .config <<'CFG'
CONFIG_PPC_EARLY_DEBUG=y
CONFIG_PPC_EARLY_DEBUG_FSL_UART=y
CONFIG_PPC_EARLY_DEBUG_PHYS_ADDR=0xffe04500
CFG

export PATH="$TC/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

# olddefconfig accepts our forced flags
yes "" | make olddefconfig 2>&1 | tail -10

# Verify
grep -E "PPC_EARLY_DEBUG" .config | head -10
