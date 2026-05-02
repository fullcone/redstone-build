# Redstone (R0678) ImmortalWrt Build

ImmortalWrt 24.10.6 based bring-up for Edgecore-style P2020 + BCM56846 switches.
Multi-board (Redstone / AS5612 / future SFP variants) reuse via shared SDK package.

## Architecture

- **Local (Windows + WSL)**: edit small files (DTS, patches, scripts), `git push`.
- **Remote (172.16.0.143:/mnt/nvme/redstone-build/)**: auto-checkout via post-receive hook,
  run buildroot, output stays on the 1.9 TB nvme. Only the final image (~MB) is scp'd back.

## Layout

```
boards/
  redstone/
    redstone.dts        DTS for Edgecore Redstone (R0678)
    redstone.c          board.c (machine_device_initcall)
    redstone.config     menuconfig diff (CONFIG_PACKAGE_*, CONFIG_TARGET_*)
patches/
  0001-*.patch          mpc85xx kernel patches (will pop in if upstream 6.6 still has bugs)
packages/
  bcm-sdk/              OpenBCM 6.5.27 BDE/KNET/userland wrapped as OpenWrt package (Phase 2)
scripts/
  prepare.sh            Remote-side: clone immortalwrt + apply patches + symlink boards
  build.sh BOARD        Remote-side: produce TFTP-loadable initramfs FIT image
  fetch-image.sh        Local-side: scp the .itb back from remote
```

## Quick start

```sh
# (one-time) add remote
git remote add origin root@172.16.0.143:/mnt/nvme/git/redstone-build.git

# edit -> commit -> push (auto-updates remote working tree)
git push origin main

# remote build
ssh root@172.16.0.143 'cd /mnt/nvme/redstone-build && ./scripts/build.sh redstone'

# pull image back
./scripts/fetch-image.sh redstone
```

## Status

- [x] Phase 0: ImmortalWrt 24.10.6 (kernel 6.6) cloned on remote
- [ ] Phase 1: TFTP-loadable initramfs FIT image of default `freescale_p2020rdb` boots on Redstone
  - Test if PCIe panic and eth1 (BCM54616S/gianfar) issues self-resolved on 6.6 mainline
- [ ] Phase 2: Add Redstone board profile (DTS/board.c/Device definition)
- [ ] Phase 3: Wrap OpenBCM 6.5.27 BDE/KNET/userland as OpenWrt package
- [ ] Phase 4: switchd integration (or replace with bcm.user CLI script)
- [ ] Phase 5: Multi-board (port AS5612 etc. by reusing the same SDK package)
