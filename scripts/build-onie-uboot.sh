#!/bin/bash
# Build ONIE U-Boot v2013.01.01 for AS5610-52X using ONIE upstream build system.
# Output: u-boot.bin with all 21 patches (19 generic + 2 AS5610-specific) applied.
set -ex
cd /mnt/nvme/onie/build-config

# ONIE makes need standard tools — most should already be on Ubuntu
which make gcc bzip2 wget patch || true

# Build U-Boot only (skipping kernel/onie image)
nice make -j$(nproc) MACHINEROOT=../machine/accton MACHINE=accton_as5610_52x u-boot 2>&1 | tail -30
ls -la /mnt/nvme/onie/build/images/ 2>&1
find /mnt/nvme/onie/build -name "u-boot.bin" 2>&1 | head -3
