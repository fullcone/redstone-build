# Redstone R0768-F0002-00 U-Boot TFTP Boot Cheatsheet
(R0678 = working dir codename; actual board PN = R0768-F0002-00)

Source: codex/claudecode session history mining (`docs/redstone_progress.md`,
`docs/redstone_hardware_inventory.md`, codex `04-28T23-42` L20372). All commands
below are **proven on this exact bench setup** unless flagged "untried".

## Bench network

| Role | IP / value |
|---|---|
| Target board (mgmt = eth1 = U-Boot eTSEC2) | `10.188.2.16` |
| TFTP server | `10.188.2.243` |
| External test peer / router | `10.188.2.254` |
| Target board MAC (eTSEC2) | `00:E0:EC:53:B8:23` |
| Target board MAC (U-Boot eTSEC2 was set with) | `00:E0:EC:53:B8:22` |

## One-time U-Boot env

```
setenv ipaddr     10.188.2.16
setenv serverip   10.188.2.243
setenv ethaddr    00:E0:EC:53:B8:22
setenv ethact     eTSEC2
setenv bootargs   "console=ttyS0,115200 loglevel=8 cache-sram-size=0x10000"
saveenv
```

Notes:
- **eTSEC2** is the only U-Boot-side interface that is wired to the management
  port; eTSEC1/3 are not exposed.
- The MAC address has to be set explicitly in U-Boot — autoload from EEPROM
  doesn't cover this board (bench history showed the exact value above).
- `cache-sram-size=0x10000` is required to keep P2020 L2 SRAM allocated
  through Linux init.
- Initramfs FIT images **don't need** `root=` / `init=` in bootargs.

## TFTP load + boot

Each time you have a new image to test, scp it to `10.188.2.243:/tftpboot/`,
then on the U-Boot console:

```
setenv bootm_low  0x10000000
setenv bootm_size 0x10000000
tftp 0x02000000 <image-filename>.itb
bootm 0x02000000
```

`0x02000000` is the proven load address for P2020 (default `$loadaddr`).

**`bootm_low` / `bootm_size` are mandatory per-boot env** for any kernel
larger than ~14MB (which OpenWrt 6.6 always is at ~28MB). Without them,
vendor U-Boot tries to relocate the FDT into 0–16MB which is already filled
by the kernel — fails with `Failed to allocate 0x... bytes below 0x1000000`.
**`fdt_high=0xffffffff` does NOT bypass this** on the Redstone vendor U-Boot;
the 16MB ceiling is hardcoded into the FDT alloc path. Only `bootm_low` /
`bootm_size` move the alloc region. **Do not `saveenv`** these — would break
the ONIE/EdgeNOS production boot path.

If the FIT image has multiple `configurations:` (typical when DTS Makefile
defines several variants), `bootm` needs the configuration selector:

```
bootm 0x02000000#freescale_p2020rdb           # baseline P2020RDB
bootm 0x02000000#edgecore_redstone            # once we add the redstone profile
bootm 0x02000000#accton_as5610_52x            # legacy EdgeNOS image (history)
```

If `bootm` reports `Bad Magic Number`, try:
```
imi 0x02000000                                 # show FIT image info
```
and pick a configuration name from the listed entries.

## Verifying the bench wiring before TFTP

```
mii info eTSEC2                                # should show BCM54616S @ 0x03
ping 10.188.2.243                              # ARP + ICMP from U-Boot
```

If `ping` fails:
- check the cable is in the **management** port (not the front-panel data
  ports)
- `mii read 3 0` should return non-`0xffff`
- if `eTSEC2` is missing from `mii device`, the eth subsystem hasn't been
  brought up — `mii info` (no arg) will list what's actually there

## Historical pitfalls

| Symptom | Fix |
|---|---|
| `GUNZIP: uncompress, out-of-mem or overwrite error - must RESET board` after `bootm` | Vendor U-Boot's in-place gunzip overlaps the FIT staging region for any compressed sub-image bigger than ~8MB compressed → ~14MB+ uncompressed. **Applies to both kernel AND initramfs FIT nodes.** Workaround: keep all FIT sub-images `compression = "none"`. Kernel itself can stay raw (~28MB ok). Initramfs raw cpio (~32MB) ok. Total FIT ~50MB still TFTPs fine on this Intel X722 NIC. EdgeNOS uses the same raw approach in their `uImage-b2-clean.itb`. |
| `ERROR: Failed to allocate 0x... bytes below 0x1000000. device tree - allocation error` | After de-gzipping the kernel, raw image is ~28MB and loaded at 0x0, occupying 0–0x1c00000. U-Boot's default FDT relocation looks for free RAM below 0x1000000 (16MB) — none available. **Long-term fix already in `patch-p2020-no-gzip.sh`: set KERNEL_LOADADDR=0x04000000** in p2020.mk so kernel goes to 64MB and 0–64MB stays free for FDT/initrd. (Temporary U-Boot env workaround — `setenv fdt_high 0xffffffff ; bootm` — is NOT needed once the patch is in.) |
| `ft_fixup_l2cache: FDT_ERR_NOTFOUND` (then bootm stalls) | Redstone vendor U-Boot iterates all `cpu@N` nodes during fixup; mainline OpenWrt p2020rdb DTS only declares `PowerPC,P2020@0` (single CPU, non-standard name). When the iterator reaches the missing 2nd core, it returns FDT_ERR_NOTFOUND and the fixup aborts. **Fix in `scripts/patch-p2020-dts-cpus.sh`**: rewrite the `cpus{}` block to standard `cpu@0` + `cpu@1` (P2020 is dual-core). |
| `pcie@ffe09000` panic in early kernel | DTB must `status="disabled"` the empty PCIe controller. **Test 6.6 mainline first** before manually patching — upstream may have fixed this. |
| Linux `eth1` ARP `INCOMPLETE`, `RX=0`, `TX>0` | TBI@0x11 PHY returns `0xffff`; mainline gianfar then takes the wrong "already linked" branch. Patch `drivers/net/phy/broadcom.c` (`bcm54616s_redstone_preserve_uboot_sgmii`) + DTS property. **Test 6.6 mainline first** — upstream may have fixed this. |
| `bootm` jumps then board reboots / silently hangs after `Loading Kernel Image` | KERNEL_LOADADDR / Entry must be `0x00000000`. PowerPC e500v2 kernel is linked at virt `0xc0000000` / phys `0x0` — any non-zero load address (including the `0x04000000` patched into p2020.mk earlier) means the wrapper jumps into bytes that don't match the link layout and the CPU faults silently. EdgeNOS .its uses `load=<0x00>; entry=<0x00>;` — match that. |
| `ft_fixup_l2cache` print followed by hang (with cpu@1 patched into dtb) | The vendor U-Boot's L2 cache fixup expected the EdgeNOS DTB layout, which has **only `cpu@0`** (single-core declaration is enough — the second core is brought up later by Linux SMP code). Adding cpu@1 is a *reverse* patch — undo `scripts/patch-p2020-dts-cpus.sh`. The original 5.10 EdgeNOS dtb at `_external/edgenos/build/linux-5.10.224/arch/powerpc/boot/dts/redstone-stage1.dtb` is the verified shape. |
| `gianfar: Device model property missing` | DTS eTSEC node needs `model = "eTSEC"`. |
| `usb@22000: Invalid 'dr_mode'` | DTS USB node needs `dr_mode = "host"`. |
| TFTP works in U-Boot but not in Linux | Indicates Linux gianfar SerDes/PCS RX path is broken — see eth1 `RX=0` row above. |
| Bench host TFTP timeouts | `10.188.2.243` runs the TFTP server on an Intel X722 NIC — **not a U-Boot issue**. Verify with `ping` first. |

## Recovering a soft-bricked board

If you flash a bad NAND image and the board won't boot, hold reset and
interrupt U-Boot (any key when "Hit any key to stop autoboot" appears). Then
the TFTP commands above let you boot a known-good initramfs without touching
NAND. The board's NAND state can then be repaired from inside the booted
Linux.
