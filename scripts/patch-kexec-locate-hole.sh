#!/bin/bash
# Patch kexec-tools locate_hole to fall back to sequential allocation
# starting at 64MB when the standard /proc/iomem-based search fails.
# This bypasses the EdgeNOS kernel limitation where /proc/iomem only shows
# top-level System RAM, no kernel code/data sub-entries.
set -ex
KEXEC_DIR=/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32

python3 - <<'PYEOF'
path = "/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/kexec/kexec.c"
with open(path) as f:
    src = f.read()

# Find the original ULONG_MAX check + replace with a fallback hack
old = """\tif (hole_base == ULONG_MAX) {
\t\tfprintf(stderr, "Could not find a free area of memory of "
\t\t\t"0x%lx bytes...\\n", hole_size);
\t\treturn ULONG_MAX;
\t}"""

new = """\tif (hole_base == ULONG_MAX) {
\t\t/* HACK: /proc/iomem doesn't expose kernel sub-entries on this kernel.
\t\t * Fall back to sequential allocation from 64MB. */
\t\tstatic unsigned long fallback_addr = 0x4000000;
\t\tunsigned long want_align = hole_align ? hole_align : (unsigned long)getpagesize();
\t\thole_base = (fallback_addr + want_align - 1) & ~(want_align - 1);
\t\tfallback_addr = hole_base + hole_size + 0x10000;
\t\tfprintf(stderr, "locate_hole HACK: 0x%lx size 0x%lx\\n", hole_base, hole_size);
\t}"""

if old not in src:
    print("ORIGINAL not found — checking if already patched")
    if "locate_hole HACK" in src:
        print("already patched")
    else:
        # Try with different whitespace — find the original via simpler regex
        import re
        # Restore from .orig if exists
        try:
            with open(path + ".orig") as o:
                src = o.read()
                print("restored from .orig")
        except FileNotFoundError:
            pass
        if old not in src:
            # Try direct text find (handle existing manual patch)
            # If hack already inserted, leave alone
            print("Cannot find ORIGINAL pattern; attempting alternative approach")
            import sys
            sys.exit(1)

# Save original first time
import os
if not os.path.exists(path + ".orig"):
    with open(path + ".orig", "w") as o:
        with open(path) as f:
            o.write(f.read())

src = src.replace(old, new)
with open(path, "w") as f:
    f.write(src)
print("patched OK")
PYEOF

grep -B 1 -A 8 "locate_hole HACK" "$KEXEC_DIR/kexec/kexec.c" | head -15

# Rebuild kexec
cd /mnt/nvme/openwrt-2203
make FORCE_UNSAFE_CONFIGURE=1 -j$(nproc) package/kexec-tools/{compile,install} 2>&1 | tail -5

ls -la "$KEXEC_DIR/build/sbin/kexec"
