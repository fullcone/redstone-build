# Redstone R0768-F0002-00 — OpenWrt 22.03 production base

Build target: Edgecore Redstone R0768-F0002-00 (Freescale P2020 PowerPC e500v2,
BCM56846 ASIC, BCM84848 PHY).

> Working dir name `R0678` is the codename. The actual board PN is `R0768-F0002-00`.
> EdgeNOS internal naming "AS5610-52X" is a NOS-internal label, not the vendor SKU.

## Why OpenWrt 22.03 (kernel 5.10) and not newer

Mainline PPC32 `head_85xx.S` regression between 5.10 and 5.15. Tested 5.15.180,
6.6.135, and 6.12.85 — all silent on this hardware after `kexec_core: Bye!`.
5.10 boots cleanly. See `memory/project_kernel_regression.md` for the test
matrix and `memory/project_baseline_22_03.md` for the pivot rationale.

## Layout

```
inputs/                          immutable build inputs (committed)
  edgenos/
    config/as5610_defconfig        vendor kernel defconfig
    patches/0001-gianfar-*.patch   TBI fix
    patches/0002-bcm54616s-*.patch SGMII preserve fix
    dts/redstone-stage1.dts        Redstone PPC dts (vendor)
  dtb/
    clean-dtb-1.dts                vendor reference (do not edit)
    redstone.dts                   our patched dts (committed deltas)

config/
  p3-switch.config               package additions for switch role (frr, lldpd, snmpd, ...)

files/                           static files copied as-is into image rootfs
  etc/
    frr/{daemons,frr.conf}         FRR daemon selector + skeleton config
    snmp/snmpd.conf                snmpd v2c read-only template
    lldpd.d/redstone.conf          LLDP advertise config
    chrony/chrony.conf             NTP client+server (mgmt subnet)
    uci-defaults/99-redstone-switch first-boot config (hostname / mgmt IP / firewall)
  usr/local/bin/redstone-info    quick-look diag (`redstone-info`)

scripts/
  build-prod-base.sh             main orchestrator (idempotent)
  diy-script.sh                  applies P3 config + files/ before initramfs build
  ...                            one-off helpers from kexec investigation (kept for reference)

output/                          FIT image + md5 + log (gitignored)
cache/                           kernel src, padded dtb, modules tree (gitignored)
```

The build host (which `build-prod-base.sh` reads/writes from) is `root@172.16.0.143`,
all under `/mnt/nvme/redstone-build/`. See `memory/reference_remote_paths.md`.

## Build

```sh
ssh root@172.16.0.143
bash /mnt/nvme/redstone-build/scripts/build-prod-base.sh
```

Idempotent. Pass `--rebuild-kernel` or `--rebuild-userspace` to force a stage.
Output: `/mnt/nvme/redstone-build/output/redstone-prod-base.itb`.

## Deploy

```
uboot> tftp 0x10000000 redstone-prod-base.itb
uboot> bootm 0x10000000
```

## What's in the base image

- **Kernel**: EdgeNOS 5.10.224 + 2 vendor patches (gianfar TBI fix,
  BCM54616S SGMII preserve) + `CONFIG_KEXEC=y`
- **Userspace**: OpenWrt 22.03 mpc85xx_p2020 default initramfs
  (busybox + dropbear + opkg)
- **DTB**: Redstone verified, 4KB padded so vendor U-Boot has space to setprop
  `chosen.linux,stdout-path` without `chosen node create failed`

## Roadmap

| #   | Goal                                                         | Depends |
|-----|--------------------------------------------------------------|---------|
| P1  | Reproducible base image build (this script)                  | —       |
| P2  | NOR/NAND squashfs+overlay rootfs (drop initramfs-only)       | P1      |
| P3  | Switch package set + diy-script (frr, lldpd, snmpd, mstpd)   | P1      |
| P4  | FRR control-plane POC (software forwarding)                  | P3      |
| P5  | GitHub Actions CI                                            | parallel|
| P6  | BCM SDK package + zebra hardware offload                     | P4      |
