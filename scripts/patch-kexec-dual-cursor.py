#!/usr/bin/env python3
# Replace single fallback_addr with dual cursor (high/low) so locate_hole
# can satisfy requests with hole_max constraint.
p = "/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/kexec/kexec.c"
s = open(p).read()

# Find existing HACK block and replace
import re
old_block = re.search(
    r"\tif \(hole_base == ULONG_MAX\) \{[^}]*locate_hole HACK[^}]*\}",
    s, re.DOTALL,
)
if not old_block:
    print("FAIL: HACK block not found")
    raise SystemExit(1)

new = """\tif (hole_base == ULONG_MAX) {
\t\t/* HACK: dual-cursor fallback. /proc/iomem lacks kernel sub-entries.
\t\t * high_cursor: 64MB+ for unconstrained allocs (kernel, ramdisk).
\t\t * low_cursor:  16MB+ for hole_max-constrained small allocs. */
\t\tstatic unsigned long high_cursor = 0x4000000;
\t\tstatic unsigned long low_cursor  = 0x1000000;
\t\tunsigned long want_align = hole_align ? hole_align : (unsigned long)getpagesize();
\t\tunsigned long *cursor;
\t\tunsigned long start;
\t\tif (hole_max && hole_max <= high_cursor) {
\t\t\tcursor = &low_cursor;
\t\t} else {
\t\t\tcursor = &high_cursor;
\t\t}
\t\tstart = *cursor;
\t\tif (hole_min > start) start = hole_min;
\t\thole_base = (start + want_align - 1) & ~(want_align - 1);
\t\tif (hole_max && (hole_base + hole_size > hole_max)) {
\t\t\tfprintf(stderr, "locate_hole HACK FAIL: need 0x%lx in [0x%lx, 0x%lx]\\n",
\t\t\t\thole_size, hole_min, hole_max);
\t\t\treturn ULONG_MAX;
\t\t}
\t\t*cursor = hole_base + hole_size + 0x10000;
\t\tfprintf(stderr, "locate_hole HACK: 0x%lx size 0x%lx (cursor=%s)\\n",
\t\t\thole_base, hole_size, cursor==&low_cursor?"low":"high");
\t}"""

s = s[:old_block.start()] + new + s[old_block.end():]
open(p, "w").write(s)
print("patched OK")
