# Redstone (R0678) U-Boot TFTP Boot Cheatsheet

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
tftp 0x02000000 <image-filename>.itb
bootm 0x02000000
```

`0x02000000` is the proven load address for P2020 (default `$loadaddr`).

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
| `GUNZIP: uncompress, out-of-mem or overwrite error - must RESET board` after `bootm` | OpenWrt mpc85xx p2020.mk uses gzip-compressed kernel inside FIT. At ~14MB compressed → ~30MB decompressed, the in-place gunzip target overlaps the FIT image staging region. **Fix: patch `target/linux/mpc85xx/image/p2020.mk` to drop `gzip |` from KERNEL pipeline and use `fit none` instead of `fit gzip`.** Already automated in `scripts/patch-p2020-no-gzip.sh`, called by `scripts/build.sh`. |
| `pcie@ffe09000` panic in early kernel | DTB must `status="disabled"` the empty PCIe controller. **Test 6.6 mainline first** before manually patching — upstream may have fixed this. |
| Linux `eth1` ARP `INCOMPLETE`, `RX=0`, `TX>0` | TBI@0x11 PHY returns `0xffff`; mainline gianfar then takes the wrong "already linked" branch. Patch `drivers/net/phy/broadcom.c` (`bcm54616s_redstone_preserve_uboot_sgmii`) + DTS property. **Test 6.6 mainline first** — upstream may have fixed this. |
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
