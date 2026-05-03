#!/bin/bash
# Clone ONIE upstream + find U-Boot version + AS5610-52X patches
set -ex
cd /mnt/nvme

if [ ! -d onie ]; then
    git clone --depth 1 https://github.com/opencomputeproject/onie.git
fi

cd onie

echo "=== AS5610-52X machine config ==="
cat machine/accton/accton_as5610_52x/machine.make 2>&1 | grep -iE "UBOOT|KERNEL_VER|ARCH"

echo
echo "=== U-Boot version used by AS5610-52X ==="
ls machine/accton/accton_as5610_52x/u-boot/

echo
echo "=== ONIE upstream U-Boot version ==="
grep -E "UBOOT_VERSION|U_BOOT_VERSION|uboot.*version" build-config/make/uboot.make 2>&1 | head -10

echo
echo "=== U-Boot patches for AS5610-52X ==="
ls machine/accton/accton_as5610_52x/u-boot/*.patch 2>/dev/null

echo
echo "=== machine.make full ==="
cat machine/accton/accton_as5610_52x/machine.make
