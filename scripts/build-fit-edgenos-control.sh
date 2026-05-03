#!/bin/bash
# Control image: take EdgeNOS-built kernel.bin + initramfs.cpio + dtb,
# repack with our own .its template (EdgeNOS-style: load=0 entry=0 +
# kernel + ramdisk + fdt). If THIS boots cleanly via our FIT path, then
# the FIT pipeline is fine and the OpenWrt 6.6 kernel itself is what's
# incompatible with vendor U-Boot's boot ABI on Redstone.

set -eu

OUT=/mnt/nvme/immortalwrt/redstone-fit
MKIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
SRC=/tmp/edgenos-components
mkdir -p "$OUT" "$SRC"
cd "$OUT"

# We expect /tmp/edgenos-components/{kernel.bin,initramfs.cpio,dtb} to be
# scp'd in by the wrapper script before this runs.
ls -la "$SRC"/

cp -f "$SRC/kernel.bin"     ekernel.bin
cp -f "$SRC/initramfs.cpio" einitramfs
cp -f "$SRC/dtb"            edtb

cat > edgenos-control.its <<'ITS'
/dts-v1/;
/ {
    description = "Control: EdgeNOS kernel/initramfs/dtb via our FIT wrapper";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "EdgeNOS 5.10 PowerPC kernel (raw)";
            data = /incbin/("ekernel.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };

        initramfs {
            description = "EdgeNOS B2 initramfs.cpio";
            data = /incbin/("einitramfs");
            type = "ramdisk";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
        };

        fdt {
            description = "EdgeNOS redstone stage1 dtb";
            data = /incbin/("edtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };

    configurations {
        default = "redstone";

        redstone {
            description = "EdgeNOS components, our wrapper";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt";
        };
    };
};
ITS

"$MKIMAGE" -f edgenos-control.its edgenos-control.itb 2>&1 | tail -3
ls -la edgenos-control.itb
echo
"$MKIMAGE" -l edgenos-control.itb 2>&1 | head -30
