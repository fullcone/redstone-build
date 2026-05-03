#!/bin/bash
# Pack simpleImage.redstone-stage1 (PowerPC boot wrapper, ~13.6MB) +
# OpenWrt's initramfs.cpio + EdgeNOS verified dtb into a FIT image.
# Goal: bypass the raw-vmlinux ABI mismatch — wrapper does the e500 CAM/MMU
# setup and r3/r6 setup that mainline kernel head_fsl_booke.S expects.

set -eu

KSRC=/mnt/nvme/immortalwrt/build_dir/target-powerpc_8548_musl/linux-mpc85xx_p2020/linux-6.6.135
OUT=/mnt/nvme/immortalwrt/redstone-fit
MKIMAGE=/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage
mkdir -p "$OUT"
cd "$OUT"

cp -f "$KSRC/arch/powerpc/boot/simpleImage.redstone-stage1" simplekernel.bin
cp -f "$KSRC/usr/initramfs_data.cpio"                       initramfs.cpio
# Use the padded clean dtb we already proved past chosen fixup
cp -f /tmp/dtb-diff/clean-dtb-1.dtb redstone.dtb
dtc -I dtb -O dts redstone.dtb -o redstone.dts 2>/dev/null

# wrapper console probe (arch/powerpc/boot/serial.c:serial_get_stdout_devp)
# requires chosen.{linux,stdout-path|stdout-path}. EdgeNOS dtb only has
# `bootargs = [00]` in chosen — wrapper finds no console and silently noop's
# all writes. Add stdout-path so wrapper can init ns16550 + emit
# "zImage starting:" early prints. Use awk (sed substitution wasn't matching
# because of unpredictable whitespace around `bootargs = [00];`).
awk '
    BEGIN { in_chosen=0; in_memory=0 }
    /chosen {/ { in_chosen=1 }
    in_chosen && /bootargs/ {
        print "\t\tbootargs = \"console=ttyS0,115200 root=/dev/ram rw ramdisk_size=3000000 cache-sram-size=0x10000\";"
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
echo "patched chosen{} + memory{}:"
sed -n '/chosen/,/};/p ; /^\tmemory/,/};/p' redstone.dts | head -15

dtc -I dts -O dtb -p 0x1000 redstone.dts -o redstone-padded.dtb 2>/dev/null
echo "patched chosen{} adds stdout-path:"
grep -A 3 "chosen" redstone.dts | head -6

ls -la simplekernel.bin initramfs.cpio redstone-padded.dtb

cat > redstone-simple.its <<'ITS'
/dts-v1/;
/ {
    description = "OpenWrt 6.6 simpleImage + initramfs + padded EdgeNOS dtb";
    #address-cells = <0x01>;

    images {
        kernel {
            description = "OpenWrt 6.6.135 simpleImage.redstone-stage1 (wrapper @ 0x1800000)";
            data = /incbin/("simplekernel.bin");
            type = "kernel";
            arch = "ppc";
            os = "linux";
            compression = "none";
            load = <0x01800000>;
            entry = <0x01800000>;
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
            description = "Redstone bring-up via simpleImage wrapper";
            kernel = "kernel";
            ramdisk = "initramfs";
            fdt = "fdt";
        };
    };
};
ITS

"$MKIMAGE" -f redstone-simple.its redstone-simple.itb 2>&1 | tail -3
ls -la redstone-simple.itb
echo
"$MKIMAGE" -l redstone-simple.itb 2>&1 | head -35
