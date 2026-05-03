#!/bin/bash
# Redstone R0768-F0002-00 production base image builder
#
# Inputs (under $REDSTONE/inputs/):
#   edgenos/config/as5610_defconfig
#   edgenos/patches/{0001,0002}-*.patch
#   edgenos/dts/redstone-stage1.dts
#   dtb/redstone.dts               (patched Redstone dtb source: pci=realloc cmdline,
#                                    PCIe gen2, l2-cache linux,phandle, drop unused i2c)
#
# Outputs (under $REDSTONE/output/):
#   redstone-prod-base.itb         (FIT image, ready to TFTP)
#   redstone-prod-base.itb.md5
#   BUILD.log
#
# Build is idempotent: skips kernel rebuild if intermediate cached and config unchanged.
#
# Usage:  bash build-prod-base.sh [--rebuild-kernel] [--rebuild-userspace]

set -eo pipefail

REDSTONE=/mnt/nvme/redstone-build
OPENWRT=/mnt/nvme/openwrt-2203
TC=$OPENWRT/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
MK=$OPENWRT/staging_dir/host/bin/mkimage
CACHE=$REDSTONE/cache
OUT=$REDSTONE/output
LOG=$OUT/BUILD.log

REBUILD_KERNEL=0
REBUILD_USERSPACE=0
for arg in "$@"; do
    case "$arg" in
        --rebuild-kernel)    REBUILD_KERNEL=1 ;;
        --rebuild-userspace) REBUILD_USERSPACE=1 ;;
        --help|-h)
            sed -n '2,18p' "$0"; exit 0 ;;
    esac
done

mkdir -p "$CACHE" "$OUT"
exec > >(tee -a "$LOG") 2>&1
echo "=== build-prod-base.sh starting at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# --- Sanity check inputs ---------------------------------------------------
for f in \
    "$REDSTONE/inputs/edgenos/config/as5610_defconfig" \
    "$REDSTONE/inputs/edgenos/patches/0001-gianfar-log-and-force-invalid-tbi-setup.patch" \
    "$REDSTONE/inputs/edgenos/patches/0002-bcm54616s-redstone-preserve-uboot-sgmii.patch" \
    "$REDSTONE/inputs/edgenos/dts/redstone-stage1.dts" \
    "$REDSTONE/inputs/dtb/redstone.dts" \
    "$MK" "$TC/bin/powerpc-openwrt-linux-musl-gcc"
do
    [ -f "$f" ] || { echo "MISSING INPUT: $f"; exit 1; }
done
echo "[OK] inputs verified"

# --- Compute config hash for cache invalidation ----------------------------
CFG_HASH=$(cat "$REDSTONE/inputs/edgenos/config/as5610_defconfig" \
                "$REDSTONE/inputs/edgenos/patches/"*.patch \
                "$REDSTONE/inputs/edgenos/dts/redstone-stage1.dts" \
                "$REDSTONE/inputs/dtb/redstone.dts" \
            | sha256sum | cut -c1-12)
KERNEL_BIN=$CACHE/edgenos-510-${CFG_HASH}.bin
echo "[INFO] config hash: $CFG_HASH"

# --- Stage 1: EdgeNOS 5.10 kernel rebuild ----------------------------------
if [ ! -f "$KERNEL_BIN" ] || [ "$REBUILD_KERNEL" = 1 ]; then
    echo "[BUILD] EdgeNOS 5.10.224 kernel (cache miss or forced)"
    KSRC=$CACHE/linux-5.10.224
    if [ ! -d "$KSRC" ]; then
        cd "$CACHE"
        if [ ! -f linux-5.10.224.tar.xz ]; then
            wget -q https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.224.tar.xz
        fi
        tar xf linux-5.10.224.tar.xz
    fi
    cd "$KSRC"

    # apply patches (idempotent)
    for p in "$REDSTONE/inputs/edgenos/patches/"*.patch; do
        if patch -p1 --dry-run --forward < "$p" >/dev/null 2>&1; then
            patch -p1 < "$p"
            echo "  applied: $(basename "$p")"
        else
            echo "  skip (already applied or fails): $(basename "$p")"
        fi
    done

    # install dts + Makefile entry (idempotent)
    cp -f "$REDSTONE/inputs/edgenos/dts/redstone-stage1.dts" arch/powerpc/boot/dts/
    grep -q "redstone-stage1.dtb" arch/powerpc/boot/dts/Makefile || \
        echo 'dtb-$(CONFIG_PPC_85xx) += redstone-stage1.dtb' >> arch/powerpc/boot/dts/Makefile

    cp -f "$REDSTONE/inputs/edgenos/config/as5610_defconfig" .config
    echo "CONFIG_KEXEC=y"      >> .config   # for future flexibility
    echo "CONFIG_CRASH_DUMP=n" >> .config

    export PATH="$TC/bin:$PATH"
    export STAGING_DIR=$OPENWRT/staging_dir/target-powerpc_8540_musl
    export CROSS_COMPILE=powerpc-openwrt-linux-musl-
    export ARCH=powerpc

    set +o pipefail
    yes "" | make olddefconfig 2>&1 | tail -3
    make -j"$(nproc)" vmlinux modules 2>&1 | tail -5
    set -o pipefail
    "$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary vmlinux "$KERNEL_BIN"

    # Stage modules into a clean tree for cpio overlay
    MODS_TREE=$CACHE/mods-${CFG_HASH}
    rm -rf "$MODS_TREE"
    mkdir -p "$MODS_TREE"
    make INSTALL_MOD_PATH="$MODS_TREE" INSTALL_MOD_STRIP=1 modules_install 2>&1 | tail -3
    # Drop build/source symlinks (only useful for compiling out-of-tree)
    find "$MODS_TREE/lib/modules" -maxdepth 2 -type l \( -name build -o -name source \) -delete 2>/dev/null || true
    echo "[OK] kernel built → $KERNEL_BIN ($(stat -c%s "$KERNEL_BIN") bytes)"
    echo "[OK] modules installed → $MODS_TREE ($(du -sm "$MODS_TREE" | cut -f1) MB)"
else
    echo "[CACHE] kernel hit: $KERNEL_BIN"
fi
MODS_TREE=$CACHE/mods-${CFG_HASH}

# --- Stage 2: OpenWrt 22.03 userspace initramfs -----------------------------
INITRAMFS=$OPENWRT/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio
if [ ! -f "$INITRAMFS" ] || [ "$REBUILD_USERSPACE" = 1 ]; then
    echo "[BUILD] OpenWrt 22.03 userspace (initramfs)"
    cd "$OPENWRT"
    set +o pipefail
    make -j"$(nproc)" target/linux/compile V=s 2>&1 | tail -10
    set -o pipefail
    [ -f "$INITRAMFS" ] || { echo "ERROR: initramfs not produced"; exit 1; }
    echo "[OK] initramfs: $INITRAMFS ($(stat -c%s "$INITRAMFS") bytes)"
else
    echo "[OK] initramfs reuse: $INITRAMFS ($(stat -c%s "$INITRAMFS") bytes)"
fi

# --- Stage 2.5: assemble combined cpio (base initramfs + /lib/modules) -----
COMBINED_CPIO=$CACHE/initramfs-with-modules-${CFG_HASH}.cpio
if [ ! -f "$COMBINED_CPIO" ] || [ "$REBUILD_KERNEL" = 1 ] || [ "$REBUILD_USERSPACE" = 1 ]; then
    EXTRA_DIR=$CACHE/extra-stage
    rm -rf "$EXTRA_DIR"
    mkdir -p "$EXTRA_DIR/lib"
    cp -a "$MODS_TREE/lib/modules" "$EXTRA_DIR/lib/"
    EXTRA_CPIO=$CACHE/extra-mods.cpio
    ( cd "$EXTRA_DIR" && find . | cpio -o -H newc 2>/dev/null > "$EXTRA_CPIO" )
    cat "$INITRAMFS" "$EXTRA_CPIO" > "$COMBINED_CPIO"
    echo "[OK] combined cpio: $COMBINED_CPIO ($(stat -c%s "$COMBINED_CPIO") bytes, extra modules $(stat -c%s "$EXTRA_CPIO") bytes)"
else
    echo "[CACHE] combined cpio: $COMBINED_CPIO"
fi

# --- Stage 3: compile + pad dtb (4KB padding for vendor U-Boot setprop) ----
DTB_PAD=$CACHE/redstone-padded.dtb
DTC=$(command -v dtc)
[ -z "$DTC" ] && DTC=$OPENWRT/staging_dir/host/bin/dtc
"$DTC" -I dts -O dtb -p 0x1000 "$REDSTONE/inputs/dtb/redstone.dts" -o "$DTB_PAD"
echo "[OK] dtb compiled+padded: $DTB_PAD ($(stat -c%s "$DTB_PAD") bytes)"

# --- Stage 4: assemble FIT --------------------------------------------------
ITS=$CACHE/redstone-prod-base.its
ITB=$OUT/redstone-prod-base.itb
GIT_REV="22.03+EdgeNOS5.10-${CFG_HASH}"

cat > "$ITS" <<ITS
/dts-v1/;
/ {
    description = "Redstone R0768-F0002-00 production base ($GIT_REV, built $(date -u +%Y-%m-%d))";
    #address-cells = <0x01>;
    images {
        kernel {
            description = "EdgeNOS 5.10.224 + KEXEC";
            data = /incbin/("$KERNEL_BIN");
            type = "kernel"; arch = "ppc"; os = "linux"; compression = "none";
            load = <0x00>; entry = <0x00>;
        };
        initramfs {
            description = "OpenWrt 22.03 initramfs + EdgeNOS 5.10 modules";
            data = /incbin/("$COMBINED_CPIO");
            type = "ramdisk"; arch = "ppc"; os = "linux"; compression = "none";
            load = <0x00>;
        };
        fdt {
            description = "Redstone verified dtb (4KB padded)";
            data = /incbin/("$DTB_PAD");
            type = "flat_dt"; arch = "ppc"; os = "linux"; compression = "none";
        };
    };
    configurations {
        default = "redstone";
        redstone {
            kernel = "kernel"; ramdisk = "initramfs"; fdt = "fdt";
        };
    };
};
ITS

"$MK" -f "$ITS" "$ITB" 2>&1 | tail -5
md5sum "$ITB" | tee "$ITB.md5"
echo "[OK] FIT image: $ITB ($(stat -c%s "$ITB") bytes)"
echo "=== build complete at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo
echo "Deploy:"
echo "  scp $ITB <tftp-server>:/srv/tftp/"
echo "  uboot> tftp 0x10000000 redstone-prod-base.itb"
echo "  uboot> bootm 0x10000000"
