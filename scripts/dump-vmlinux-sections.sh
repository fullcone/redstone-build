#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
OD="$TC/bin/powerpc-openwrt-linux-musl-objdump"
"$OD" -h "$KSRC/vmlinux" 2>&1 | head -55
