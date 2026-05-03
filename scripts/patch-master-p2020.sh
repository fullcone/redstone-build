#!/bin/bash
# Patch master's freescale_p2020rdb device definition to use zImage.la3000000
# wrapper + no compression + load=entry=0 — exactly what watchguard_xtm330
# (same SoC) already uses successfully in master.
set -ex
P=/mnt/nvme/openwrt-master/openwrt/target/linux/mpc85xx/image/p2020.mk

cp -f "$P" "$P.bak"

python3 - <<'PY'
import re
path = '/mnt/nvme/openwrt-master/openwrt/target/linux/mpc85xx/image/p2020.mk'
src = open(path).read()

# Replace the freescale_p2020rdb KERNEL block to mirror watchguard_xtm330
new_kernel = (
    '  KERNEL = kernel-bin | fit none $(KDIR)/image-$$(DEVICE_DTS).dtb\n'
    '  KERNEL_NAME := zImage.la3000000\n'
    '  KERNEL_ENTRY := 0x03000000\n'
    '  KERNEL_LOADADDR := 0x03000000'
)

# Match the existing KERNEL := ... fit gzip ... line
pattern = re.compile(
    r'  KERNEL := kernel-bin \| libdeflate-gzip \| \\\n'
    r'\tfit gzip \$\$\(KDIR\)/image-\$\$\(firstword \$\$\(DEVICE_DTS\)\)\.dtb',
    re.M
)
new_src, n = pattern.subn(new_kernel, src, count=1)
if n != 1:
    print(f'WARNING: replaced {n} times')
open(path, 'w').write(new_src)
print('patched')
PY

# Show the new freescale_p2020rdb block
sed -n '/define Device\/freescale_p2020rdb/,/^endef/p' "$P"
