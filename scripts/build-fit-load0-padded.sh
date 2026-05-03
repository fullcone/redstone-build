#!/bin/bash
# Same as build-fit-load0.sh but rebuild the dtb with 4KB internal padding
# (dtc -p 0x1000) so vendor U-Boot's fdt fixup pass — which adds
# /chosen/linux,stdout-path among other things — can fdt_setprop() without
# 'FDT_ERR_NOTFOUND'/'/chosen node create failed'.

set -eu

KDIR=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020
OUT=/mnt/nvme/immortalwrt/redstone-fit
MKIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

# Source dtb: prefer the clean-dtb-1.dtb (extracted from EdgeNOS's known-working
# uImage-b2-clean.itb — that proves it's the dtb shape vendor U-Boot accepts).
# Re-encode with 4KB padding so any fixup-time setprop has headroom.
SRC_DTB=/tmp/dtb-diff/clean-dtb-1.dtb
[ -f "$SRC_DTB" ] || SRC_DTB=/tmp/edgenos-components/dtb
echo "source dtb: $SRC_DTB"
dtc -I dtb -O dts "$SRC_DTB" -o redstone-padded.dts 2>/dev/null
dtc -I dts -O dtb -p 0x1000 redstone-padded.dts -o redstone-padded.dtb 2>/dev/null
ls -la "$SRC_DTB" redstone-padded.dtb

cp -f "$KDIR/vmlinux-initramfs" kernel.bin

cat > redstone-padded.its <<'ITS'
/dts-v1/;
/ {
    description = "OpenWrt 6.6 + padded EdgeNOS dtb (4KB headroom for fixup)";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "OpenWrt 6.6.135 PowerPC e500v2 (load=0)";
            data = /incbin/("kernel.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
            entry = <0x00>;
        };

        fdt {
            description = "EdgeNOS clean dtb + 4KB padding";
            data = /incbin/("redstone-padded.dtb");
            type = "flat_dt";
            arch = "ppc";
            os = "linux";
            compression = "none";
        };
    };

    configurations {
        default = "redstone";
        redstone {
            description = "Redstone bring-up (padded dtb)";
            kernel = "kernel";
            fdt = "fdt";
        };
    };
};
ITS

"$MKIMAGE" -f redstone-padded.its redstone-load0-padded.itb 2>&1 | tail -3
ls -la redstone-load0-padded.itb
