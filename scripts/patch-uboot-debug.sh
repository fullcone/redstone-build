#!/bin/bash
# Add DIRECT UART mmio write at very first instruction of mainline U-Boot
# _start. If we see 'M' on console after `go 0x11000000`, chainload reached
# _start; if not, jump itself fails (vendor U-Boot's MMU/cache state breaks
# instruction fetch at 0x11000000).
set -ex
cd /mnt/nvme/uboot-mainline/u-boot

# Insert debug write right after _start: label
python3 - <<'PY'
import re
path = 'arch/powerpc/cpu/mpc85xx/start.S'
src = open(path).read()
debug_block = """\
/* DEBUG: write 'M' to P2020 UART0 mmio at very first instruction */
\tlis\tr1, 0xffe0
\tori\tr1, r1, 0x4500
\tli\tr2, 0x4d  /* 'M' */
\tstb\tr2, 0(r1)
\tsync
"""
# Insert after `_start:` line (only once)
if '/* DEBUG: write' not in src:
    src = re.sub(r'^_start:\n', '_start:\n' + debug_block, src, count=1, flags=re.M)
    open(path, 'w').write(src)
    print('patched')
else:
    print('already patched')
PY

# Verify
grep -A 8 "^_start:" arch/powerpc/cpu/mpc85xx/start.S | head -12

# Rebuild
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
export PATH="$TC/bin:$PATH"
export STAGING_DIR=/mnt/nvme/immortalwrt/staging_dir/target-powerpc_8548_musl
export CROSS_COMPILE=powerpc-openwrt-linux-musl-
export ARCH=powerpc

make -j$(nproc) 2>&1 | tail -8
ls -la u-boot.bin
