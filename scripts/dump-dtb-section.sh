#!/bin/bash
KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl

echo "=== Dump .kernel:dtb section ==="
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -j .kernel:dtb -O binary \
    "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1.elf" /tmp/extracted-dtb.bin

ls -la /tmp/extracted-dtb.bin
xxd /tmp/extracted-dtb.bin | head -3

echo
echo "=== Decode extracted dtb to dts ==="
/usr/bin/dtc -I dtb -O dts /tmp/extracted-dtb.bin -o /tmp/extracted.dts 2>&1 | head -5
sed -n '/chosen/,/};/p ; /memory/,/};/p' /tmp/extracted.dts | head -15
