#!/bin/bash
# Pack zImage.la3000000 (PowerPC compressed wrapper linked at 0x03000000 —
# OpenWrt's official fix for mainline 6.6 vmlinux > 16MB on mpc85xx) +
# raw initramfs cpio + EdgeNOS clean dtb (with stdout-path + memory.reg
# pre-patched for wrapper).

set -eu

KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
OUT=/mnt/nvme/immortalwrt/redstone-fit
MKIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

cp -f "$KSRC/arch/powerpc/boot/zImage.la3000000" zkernel.bin
cp -f "$KSRC/usr/initramfs_data.cpio"            initramfs.cpio
cp -f /tmp/dtb-diff/clean-dtb-1.dtb              redstone.dtb
dtc -I dtb -O dts redstone.dtb -o redstone.dts 2>/dev/null

# patch chosen + memory like before
awk '
    BEGIN { in_chosen=0; in_memory=0 }
    /chosen {/ { in_chosen=1 }
    in_chosen && /bootargs/ {
        print "\t\tbootargs = \"console=ttyS0,115200 root=/dev/ram rw ramdisk_size=3000000\";"
        next
    }
    in_chosen && /};/ {
        print "\t\tstdout-path = \"/soc@ffe00000/serial@4600\";"
        in_chosen=0
    }
    /memory {/ { in_memory=1 }
    in_memory && /};/ {
        print "\t\treg = <0x0 0x0 0x0 0x80000000>;"
        in_memory=0
    }
    { print }
' redstone.dts > redstone-patched.dts
mv redstone-patched.dts redstone.dts

dtc -I dts -O dtb -p 0x1000 redstone.dts -o redstone-padded.dtb

ls -la zkernel.bin initramfs.cpio redstone-padded.dtb

cat > redstone-la3000000.its <<'ITS'
/dts-v1/;
/ {
    description = "OpenWrt 6.6 zImage.la3000000 + initramfs + padded dtb";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "OpenWrt 6.6.135 zImage.la3000000 (linked at 0x03000000)";
            data = /incbin/("zkernel.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x03000000>;
            entry = <0x03000000>;
        };

        initramfs {
            description = "OpenWrt initramfs raw cpio";
            data = /incbin/("initramfs.cpio");
            type = "ramdisk";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x00>;
        };

        fdt {
            description = "EdgeNOS clean dtb + 4KB padding + bootargs/memory/stdout-path patched";
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
            description = "Redstone bring-up via zImage.la3000000 (OpenWrt mpc85xx 24.10 fix)";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt";
        };
    };
};
ITS

"$MKIMAGE" -f redstone-la3000000.its redstone-la3000000.itb 2>&1 | tail -3
ls -la redstone-la3000000.itb
"$MKIMAGE" -l redstone-la3000000.itb 2>&1 | grep -E "Load|Entry|Type:|Description" | head -15
