#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
echo "=== image-y in kernel .config (CONFIG flags) ==="
grep -E "CONFIG_(TL_WDR4900_V1|HIVEAP_330|WS_AP3825I|WS_AP3710I)=" "$KSRC/.config" 2>&1
echo
echo "=== image-y resolved by Makefile expansion ==="
cd "$KSRC"
make -n -p arch/powerpc/boot/wrapper 2>/dev/null | grep -E "^image-y|^image-\\\$" | head -10
echo
echo "=== Check what dts files exist for these boards ==="
ls arch/powerpc/boot/dts/*.dts 2>/dev/null | grep -iE "hiveap|wdr4900|ap3825|ap3710" | head -10
