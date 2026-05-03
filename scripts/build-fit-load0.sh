#!/bin/bash
# Repackage existing OpenWrt kernel-bin into a FIT with load=0 entry=0
# (matching EdgeNOS .its). The previous build set KERNEL_LOADADDR=0x04000000,
# which is wrong: PowerPC kernel is linked at virt 0xc0000000 / phys 0x0,
# so any non-zero load address causes a silent hang right after bootm jumps.
# Bonus: also use the EdgeNOS-verified dtb (single cpu@0 — that's what worked
# in their stage1, our cpu@1 patch was a wrong guess).

set -eu

KDIR=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020
OUT=/mnt/nvme/immortalwrt/redstone-fit
MKIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
DUMPIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/dumpimage
mkdir -p "$OUT"
cd "$OUT"

# vmlinux-initramfs is already the raw kernel binary (objcopy -O binary done
# by Linux kbuild). 'file' shows it as plain "data". 28MB includes embedded
# initramfs.cpio.gz (kernel was built with CONFIG_TARGET_ROOTFS_INITRAMFS=y).
cp -f "$KDIR/vmlinux-initramfs" kernel.bin
cp -f /tmp/redstone-stage1.dtb dtb

HDR=$(xxd -p -l 4 kernel.bin)
echo "kernel.bin header: $HDR (expect 60000000 / non-d00dfeed PowerPC opcode)"
KFILE=kernel.bin

# Write the .its (EdgeNOS-style: load=0, entry=0, kernel+fdt, no ramdisk
# because kernel-bin already has initramfs embedded).
cat > redstone.its <<ITS
/dts-v1/;
/ {
    description = "OpenWrt 6.6 + Redstone EdgeNOS dtb";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "OpenWrt 6.6.135 PowerPC e500v2 (load=0)";
            data = /incbin/("$KFILE");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };

        fdt {
            description = "EdgeNOS verified Redstone stage1 dtb";
            data = /incbin/("dtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };

    configurations {
        default = "redstone";

        redstone {
            description = "Redstone R0768-F0002-00 bring-up";
            kernel = "kernel";
            fdt = "fdt";
        };
    };
};
ITS

"$MKIMAGE" -f redstone.its redstone-load0.itb 2>&1 | tail -5
ls -la redstone-load0.itb
echo
echo "FIT contents:"
"$MKIMAGE" -l redstone-load0.itb 2>&1 | head -25
