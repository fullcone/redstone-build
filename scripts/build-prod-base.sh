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
# Cache keying:
#   kernel  → $CFG_HASH  (sha256 of edgenos config + patches + dts + dtb)
#   modules → $CFG_HASH  (kernel modules tracks kernel hash)
#   userspace → $USER_HASH (sha256 of config/p3-switch.config + files/**)
#   combined cpio → ${CFG_HASH}-${USER_HASH}
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

# --- run_check: run a command, print last 5 lines, propagate failure --------
# Replaces the `cmd 2>&1 | tail -N` antipattern that swallows non-zero exit
# codes (codex P1 #2 + P2 #3). On failure, dumps the last 50 lines of the
# captured log so the operator can see what broke without mining BUILD.log.
run_check() {
    local logf
    logf=$(mktemp -t redstone-XXXXXX.log)
    "$@" > "$logf" 2>&1
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "FAIL ($rc): $*" >&2
        echo "----- last 50 lines of failed command output -----" >&2
        tail -50 "$logf" >&2
        rm -f "$logf"
        exit $rc
    fi
    tail -5 "$logf"
    rm -f "$logf"
}

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
MODS_TREE=$CACHE/mods-${CFG_HASH}
echo "[INFO] config hash: $CFG_HASH"

# --- Stage 1: EdgeNOS 5.10 kernel rebuild ----------------------------------
# Uses a per-CFG_HASH source tree so different inputs cannot reuse a tree
# that was patched for a different hash (codex P1 #1: dry-run patch fail
# would silently fall through and produce a kernel based on stale state).
if [ ! -f "$KERNEL_BIN" ] || [ "$REBUILD_KERNEL" = 1 ]; then
    echo "[BUILD] EdgeNOS 5.10.224 kernel (cache miss or forced)"
    KSRC=$CACHE/linux-5.10.224-${CFG_HASH}
    TARBALL=$CACHE/linux-5.10.224.tar.xz

    if [ ! -f "$TARBALL" ]; then
        ( cd "$CACHE" && wget -q https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.10.224.tar.xz )
    fi

    # Always work in a clean tree per hash. If the tree already exists for
    # this hash, trust it (only the patches/config that fed CFG_HASH could
    # have produced it). Otherwise extract fresh.
    if [ ! -d "$KSRC" ]; then
        ( cd "$CACHE" && rm -rf linux-5.10.224 && tar xf "$TARBALL" && mv linux-5.10.224 "$KSRC" )
    fi
    cd "$KSRC"

    # Apply patches with --forward; fail loudly if any patch refuses (instead
    # of silent "skip" which would let inputs/patches changes ship as no-op).
    for p in "$REDSTONE/inputs/edgenos/patches/"*.patch; do
        if patch -p1 --forward --silent --dry-run < "$p" >/dev/null 2>&1; then
            patch -p1 --silent < "$p"
            echo "  applied: $(basename "$p")"
        elif patch -p1 --reverse --silent --dry-run < "$p" >/dev/null 2>&1; then
            # Already applied to this fresh tree — only possible if patch was
            # part of an earlier extract that was preserved. Safe.
            echo "  already-applied: $(basename "$p")"
        else
            echo "FAIL: patch $p does not apply forward or reverse" >&2
            patch -p1 --forward --dry-run < "$p" >&2 || true
            exit 1
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

    # `yes "" | make olddefconfig` — yes exits 141 on SIGPIPE which would trip
    # pipefail. Use a here-string of newlines instead so there's no pipe.
    yes "" | head -n 200 > /tmp/oldconfig-yes.txt
    run_check make olddefconfig < /tmp/oldconfig-yes.txt
    rm -f /tmp/oldconfig-yes.txt

    # Real build: any compile error halts immediately with last 50 lines.
    run_check make -j"$(nproc)" vmlinux modules
    "$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary vmlinux "$KERNEL_BIN"

    # Stage modules into a clean tree for cpio overlay
    rm -rf "$MODS_TREE"
    mkdir -p "$MODS_TREE"
    run_check make INSTALL_MOD_PATH="$MODS_TREE" INSTALL_MOD_STRIP=1 modules_install
    # Drop build/source symlinks (only useful for compiling out-of-tree)
    find "$MODS_TREE/lib/modules" -maxdepth 2 -type l \( -name build -o -name source \) -delete 2>/dev/null || true
    echo "[OK] kernel built → $KERNEL_BIN ($(stat -c%s "$KERNEL_BIN") bytes)"
    echo "[OK] modules installed → $MODS_TREE ($(du -sm "$MODS_TREE" | cut -f1) MB)"
else
    echo "[CACHE] kernel hit: $KERNEL_BIN"
    [ -d "$MODS_TREE" ] || { echo "FAIL: kernel cached but modules tree missing: $MODS_TREE" >&2; exit 1; }
fi

# --- Stage 2: OpenWrt 22.03 userspace initramfs -----------------------------
INITRAMFS=$OPENWRT/build_dir/target-powerpc_8540_musl/linux-mpc85xx_p2020/linux-5.10.221/usr/initramfs_data.cpio

# Userspace cache key includes diy-script inputs so any package/files change
# triggers a rebuild. Hashing inputs only — config snippets that don't exist
# (e.g. before P3) hash to empty and don't affect the result.
USER_HASH=$(
    {
        [ -f "$REDSTONE/config/p3-switch.config" ] && cat "$REDSTONE/config/p3-switch.config"
        find "$REDSTONE/files" -type f 2>/dev/null | sort | xargs -r cat 2>/dev/null
    } | sha256sum | cut -c1-12
)
USER_STAMP=$CACHE/userspace-${USER_HASH}.stamp

if [ ! -f "$INITRAMFS" ] || [ ! -f "$USER_STAMP" ] || [ "$REBUILD_USERSPACE" = 1 ]; then
    echo "[BUILD] OpenWrt 22.03 userspace (initramfs) — userspace hash: $USER_HASH"
    cd "$OPENWRT"

    # Run diy-script (P3+): merge package config, copy /etc files, etc.
    if [ -x "$REDSTONE/scripts/diy-script.sh" ]; then
        REDSTONE="$REDSTONE" OPENWRT="$OPENWRT" run_check bash "$REDSTONE/scripts/diy-script.sh"
    fi

    # Snapshot existing initramfs mtime so we can detect "make ran but didn't
    # produce a new initramfs" — guards against codex P2 #3 false-positive
    # where a stale initramfs from a prior run satisfies the existence check.
    PREV_MTIME=$(stat -c %Y "$INITRAMFS" 2>/dev/null || echo 0)

    # Full world build: needed because diy-script may have added new packages
    # (=y in .config). target/linux/compile alone wouldn't pull them in.
    # run_check propagates failures so we can't ship a stale initramfs.
    run_check make -j"$(nproc)"

    if [ ! -f "$INITRAMFS" ]; then
        echo "FAIL: initramfs not produced at $INITRAMFS" >&2; exit 1
    fi
    NEW_MTIME=$(stat -c %Y "$INITRAMFS")
    if [ "$NEW_MTIME" -le "$PREV_MTIME" ]; then
        echo "FAIL: initramfs mtime unchanged ($PREV_MTIME → $NEW_MTIME) — make produced nothing fresh" >&2
        exit 1
    fi

    rm -f "$CACHE/userspace-"*.stamp
    touch "$USER_STAMP"
    echo "[OK] initramfs: $INITRAMFS ($(stat -c%s "$INITRAMFS") bytes)"
else
    echo "[OK] initramfs reuse: $INITRAMFS ($(stat -c%s "$INITRAMFS") bytes)"
fi

# --- Stage 2.5: assemble combined cpio (base initramfs + /lib/modules) -----
# Key by BOTH kernel CFG_HASH and userspace USER_HASH so any change in
# either input forces a rebuild.
COMBINED_CPIO=$CACHE/initramfs-with-modules-${CFG_HASH}-${USER_HASH}.cpio
if [ ! -f "$COMBINED_CPIO" ]; then
    EXTRA_DIR=$CACHE/extra-stage
    rm -rf "$EXTRA_DIR"
    mkdir -p "$EXTRA_DIR/lib"
    cp -a "$MODS_TREE/lib/modules" "$EXTRA_DIR/lib/"
    EXTRA_CPIO=$CACHE/extra-mods.cpio
    ( cd "$EXTRA_DIR" && find . | cpio -o -H newc 2>/dev/null > "$EXTRA_CPIO" )
    cat "$INITRAMFS" "$EXTRA_CPIO" > "$COMBINED_CPIO"
    echo "[OK] combined cpio: $COMBINED_CPIO ($(stat -c%s "$COMBINED_CPIO") bytes, extra modules $(stat -c%s "$EXTRA_CPIO") bytes)"
else
    echo "[CACHE] combined cpio: $COMBINED_CPIO ($(stat -c%s "$COMBINED_CPIO") bytes)"
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
GIT_REV="22.03+EdgeNOS5.10-${CFG_HASH}-${USER_HASH}"

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

run_check "$MK" -f "$ITS" "$ITB"
md5sum "$ITB" | tee "$ITB.md5"
echo "[OK] FIT image: $ITB ($(stat -c%s "$ITB") bytes)"
echo "=== build complete at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
echo
echo "Deploy:"
echo "  scp $ITB <tftp-server>:/srv/tftp/"
echo "  uboot> tftp 0x10000000 redstone-prod-base.itb"
echo "  uboot> bootm 0x10000000"
