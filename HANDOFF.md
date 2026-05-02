# Redstone (R0678) — Handoff Status

> Snapshot for next session. Last update: see `git log -1`.

## Where we are

We pivoted from "patch EdgeNOS + OpenBCM SDK on kernel 5.10" to **fresh
ImmortalWrt 24.10.6 (kernel 6.6 LTS)** as the new baseline. The bring-up plan
is now organized as Phase 1 (boot any OpenWrt image on the board) → Phase 2
(wrap OpenBCM 6.5.27 BDE/KNET/userland as an OpenWrt package).

## Architecture in place

```
Local (this machine, Windows + WSL)
└── C:\other_project\R0678\redstone-build\        ← THIS git repo
    └── images/                                    ← scp'd .itb files for TFTP

Remote builder (172.16.0.143, Ubuntu 24.04, 40 cores / 94 GB RAM)
└── /mnt/nvme/                                     ← 1.9 TB ext4
    ├── git/redstone-build.git/                    ← bare repo (push target)
    ├── redstone-build/                            ← working tree (auto-checkout via post-receive hook)
    └── immortalwrt/                               ← ImmortalWrt 24.10 source tree, feeds installed
```

Workflow: edit locally → `git push origin main` → remote checks out → `ssh
root@172.16.0.143 'cd /mnt/nvme/redstone-build && bash scripts/build.sh
baseline'` → `bash scripts/fetch-image.sh` to pull the .itb back.

SSH key auth is set up on `root@172.16.0.143` (no password needed).

## Phase 1 status

| Step | Status |
|---|---|
| ImmortalWrt 24.10.6 cloned to remote | ✅ |
| `feeds update -a && feeds install -a` | ✅ |
| `make defconfig` baseline (freescale_p2020rdb) | ✅ |
| `make -j40 world` for `freescale_p2020rdb` initramfs FIT | 🔄 in progress (Monitor `bjaz2lirx` will fire when done) |
| scp `.itb` back to `images/` locally | ⏳ auto on Monitor success |
| TFTP boot + procd prompt + eth1 reachable on Redstone | ⏳ requires you on the U-Boot console |

## What you need to do when you wake up

### 1. Verify the baseline image landed locally

```sh
ls -la C:\other_project\R0678\redstone-build\images\
# expect: openwrt-mpc85xx-p2020-freescale_p2020rdb-initramfs-fit-multi.itb (~5-10 MB)
```

If the file isn't there, the build either failed or is still running. Check:
```sh
wsl ssh root@172.16.0.143 'pgrep -af scripts/build.sh ; tail -20 /mnt/nvme/redstone-build/build.log'
```

### 2. Copy the .itb to the TFTP server (10.188.2.243)

The image needs to be in `/tftpboot/` (or whatever directory your tftpd serves)
on the TFTP host so U-Boot can fetch it. Path/method depends on your TFTP
server setup.

### 3. On the Redstone U-Boot console (serial / minicom)

See **`docs/uboot-tftp-boot.md`** for the proven command set. Quick version:

```
setenv ipaddr     10.188.2.16
setenv serverip   10.188.2.243
setenv ethaddr    00:E0:EC:53:B8:22
setenv ethact     eTSEC2
setenv bootargs   "console=ttyS0,115200 loglevel=8 cache-sram-size=0x10000"
saveenv

ping 10.188.2.243              # verify TFTP reachable
tftp 0x02000000 openwrt-mpc85xx-p2020-freescale_p2020rdb-initramfs-fit-multi.itb
bootm 0x02000000
```

If `bootm` complains about multiple configurations, list them with `imi
0x02000000` and pick:

```
bootm 0x02000000#freescale_p2020rdb
```

### 4. What outcomes mean

| Observation | Implication |
|---|---|
| Boots cleanly to procd / OpenWrt prompt + `eth1` link up | 🎉 6.6 mainline self-resolved both PCIe panic + BCM54616S issues; we can skip B3 patches and go straight to Phase 2 (BCM SDK package) |
| PCIe panic in `fsl_pcibios_fixup_phb` like before | Re-introduce the DTS fix from `_external/edgenos/kernel/dts/redstone-stage1.dts` (disable `pcie@ffe09000`); see B2 task |
| Boots, but `eth1` link up + RX=0 / ARP INCOMPLETE | Re-introduce the two patches in `patches/spare/` (BCM54616S preserve + gianfar TBI early-return); see B3 (currently deleted from task list, but the patches are there) |
| Boots, eth1 OK, but front-panel ports invisible | Expected — we haven't added BCM SDK yet. That's Phase 2 (B6). |
| U-Boot can't `tftp` | Check: cable in mgmt port; `mii info eTSEC2` shows BCM54616S @ 0x03; ping 10.188.2.243 from U-Boot. **Don't blame the kernel yet.** |

Capture serial console output to a file (most terminal apps have a "log to
file" option). After test, paste the boot log into a `bring-up-logs/` directory
in this repo and commit.

## Phase 2 plan (after Phase 1 boots)

B4: Add `boards/redstone/{redstone.dts, redstone.c, redstone.config}` —
mirror the `hiveap-330` style in ImmortalWrt's `target/linux/mpc85xx/files/`
and add a `Device/edgecore_redstone` block in `image/p2020.mk`. Most of the
DTS content can be lifted from `_external/edgenos/kernel/dts/redstone-stage1.dts`.

B6: Wrap OpenBCM 6.5.27 BDE/KNET/userland as an OpenWrt package
(`packages/bcm-sdk/Makefile`). The kernel modules (BDE/KNET) we already
verified compile + load on the previous 5.10 path; the package recipe is just
a re-build under OpenWrt's buildroot toolchain. The userland (`bcm.user`) was
~50% built when we abandoned the EdgeNOS path; full SDK needs `make bcm` to
finish (~hours on this 40-core builder).

## Monitor / background tasks

Check `Monitor bjaz2lirx` — it will notify when:
- `.itb` file appears in `bin/targets/mpc85xx/p2020/` (then it scp's it locally)
- OR `scripts/build.sh` process dies (which means build failed — check
  `build.log` on remote for the last few lines)

If both Monitor `bjaz2lirx` and the `nohup setsid bash scripts/build.sh
baseline` (PID was 2370278 on remote) are gone but no `.itb` is local, the
build was killed. Restart with:
```sh
ssh root@172.16.0.143 'cd /mnt/nvme/redstone-build && setsid nohup bash scripts/build.sh baseline > build.log 2>&1 < /dev/null &'
```
