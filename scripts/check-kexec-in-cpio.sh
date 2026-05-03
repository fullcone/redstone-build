#!/bin/bash
CPIO=/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio
ls -la "$CPIO"
echo === kexec in cpio ===
cpio -t < "$CPIO" 2>/dev/null | grep -E "kexec|sbin/k" | head -5
