#!/bin/bash
# Find which function contains the segfault address 0x12a34 in kexec binary
TC=/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl
KEXEC=/mnt/nvme/openwrt-2203/build_dir/target-powerpc_8540_musl/kexec-tools-2.0.32/build/sbin/kexec

"$TC/bin/powerpc-openwrt-linux-musl-objdump" -d "$KEXEC" > /tmp/kexec.dis 2>/dev/null

awk '
/^00[0-9a-f]+ </ { fn = $0 }
/^[[:space:]]+12a34:/ { print "FN:", fn; print "INSN:", $0 }
/^[[:space:]]+131d4:/ { print "LR-prev FN:", fn; print "INSN:", $0 }
/^[[:space:]]+131d8:/ { print "LR-at FN:", fn; print "INSN:", $0 }
' /tmp/kexec.dis | head -20
