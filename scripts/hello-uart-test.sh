#!/bin/bash
# Tiny PowerPC standalone test: infinite loop writing 'M' to P2020 UART0.
# 12 bytes total. Tests if vendor U-Boot can chainload ANY raw PowerPC code
# at 0x03000000.
set -ex
TC=/mnt/nvme/immortalwrt/staging_dir/toolchain-powerpc_8548_gcc-13.3.0_musl
mkdir -p /tmp/hello
cd /tmp/hello

cat > test.S <<'ASM'
/* Mimic zImage.la3000000 layout: first 4 bytes = `b $+0x100` */
.section .text
.globl _start
_start:
    b       _real_start          /* matches zImage wrapper pattern */
.fill 63, 4, 0x60000000           /* pad with NOPs to 0x100 */
_real_start:
    /* explicit isync to flush instruction pipeline */
    isync
    sync
    /* setup MSR with EE+ME (matches what vendor leaves in nominal state) */
    li      0, 0x3000             /* MSR_CE | MSR_EE — minimal */
    mtmsr   0
    isync
    /* now write 'M' loop */
    lis     1, 0xffe0
    ori     1, 1, 0x4500
    li      2, 0x4d
1:
    stb     2, 0(1)
    sync
    b       1b
.fill 256, 4, 0x60000000           /* pad tail with NOPs */
ASM

"$TC/bin/powerpc-openwrt-linux-musl-as" -mppc -mbig -o test.o test.S
"$TC/bin/powerpc-openwrt-linux-musl-ld" -Ttext=0x03000000 -o test.elf test.o
"$TC/bin/powerpc-openwrt-linux-musl-objcopy" -O binary test.elf test.bin
ls -la test.bin
xxd test.bin

# Wrap as Linux Kernel uImage so vendor bootm Linux path runs
/mnt/nvme/immortalwrt/staging_dir/host/bin/mkimage \
    -A ppc -O linux -T kernel -C none \
    -a 0x03000000 -e 0x03000000 \
    -n "uart M test" -d test.bin /tmp/hello/uart-test.uimg
ls -la /tmp/hello/uart-test.uimg
