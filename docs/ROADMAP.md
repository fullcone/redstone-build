# Redstone R0768-F0002-00 — Roadmap & Resume Guide

> Last update: 2026-05-03. This is the cold-start doc — read this first when resuming.

## TL;DR — where we are

We have a **reproducible production base image** (P1 ✅) booting on real hardware:
**OpenWrt 22.03 userspace + EdgeNOS 5.10.224 kernel + patched dtb** assembled by
`scripts/build-prod-base.sh`. Output: `output/redstone-prod-base.itb` (~28MB).

**P3 in progress**: switch package set (frr / lldpd / snmpd / chrony / mstpd /
collectd / ...) is added via `scripts/diy-script.sh` which patches OpenWrt
`.config` and overlays `files/`. First-boot config in
`files/etc/uci-defaults/99-redstone-switch`.

**Codex review pending**: PR #1 at `https://github.com/fullcone/redstone-build/pull/1`
already commented `@codex review`, awaiting `chatgpt-codex-connector` bot reply.

---

## Why OpenWrt 22.03 (kernel 5.10) and not newer

Mainline PPC32 `head_85xx.S` regression between 5.10 and 5.15. Tested:

| Kernel              | Result on Redstone        |
|---------------------|---------------------------|
| EdgeNOS 5.10.224    | ✅ boots (vendor)         |
| Mainline 5.15.180   | ❌ silent at "Bye!"       |
| Mainline 6.6.135    | ❌ silent at "Bye!"       |
| Mainline 6.12.85    | ❌ silent at "Bye!"       |

All three mainline kernels tested via kexec套娃 from working 5.10. kexec
hand-off confirmed clean (purgatory prints `.`) → new kernel head_85xx.S
silent. Same symptom via direct vendor-U-Boot bootm → eliminates U-Boot
leftover state as cause. Issue is in mainline ppc head itself.

**Long-term fix path** (not on critical path): bisect 5.10→5.15
head_85xx.S commits on real hardware, file PPC mailing list bug.

---

## Roadmap

### Done

- **P1** ✅ Production base image build pipeline (`scripts/build-prod-base.sh`)
- **B1** ✅ ImmortalWrt 24.10.6 baseline build (kept for reference, not production)
- **B5** ✅ TFTP boot of EdgeNOS 5.10 + OpenWrt initramfs hybrid
- Kexec套娃 / 5.15+6.6+6.12 silence investigation (all closed; saw `memory/project_kernel_regression.md`)

### In progress

- **P3** Switch package set + diy-script — building now, see `config/p3-switch.config` + `files/` + `scripts/diy-script.sh`
- **P1z** Codex review feedback on PR #1 — waiting for bot

### Pending

| #   | Goal                                                       | Blocked by | Effort | Notes                                      |
|-----|------------------------------------------------------------|------------|--------|--------------------------------------------|
| P2  | NOR/NAND squashfs+overlay rootfs (drop initramfs-only)     | P1         | M      | Map vendor partitions; add image/p2020.mk Device entry |
| P3a | Port `kennisis_cpld` driver, re-enable i2c1 thermal        | P3         | M      | Without this, BCM SDK can't reset ASIC either |
| P4  | FRR control-plane POC (BGP/OSPF software forwarding)       | P3         | S      | Lab against another switch / Linux peer    |
| P5  | GitHub Actions CI                                          | parallel   | S      | Steal pattern from `smallprogram/OpenWrtAction` |
| P6  | BCM SDK package (OpenBCM 6.5.27 BDE/KNET/userland)         | P3a, B6    | XL     | Hardware offload for FRR routes via switchdev/SAI |
| B6  | (parent of P6) BCM SDK package — vendor source needed      | —          | XL     | Dependency map: zebra → switchdev → SAI → BCM SDK |

---

## How to resume cold

### 0. Inventory check

```sh
# Local
cd C:/other_project/R0678/redstone-build
git status                         # any uncommitted work
git log --oneline -10              # recent history
git remote -v                      # origin (internal) + github (Codex)
gh pr view 1 --repo fullcone/redstone-build  # check codex feedback

# Build host
ssh root@172.16.0.143 'ls /mnt/nvme/redstone-build/output/ /mnt/nvme/redstone-build/cache/'
```

### 1. Latest image

```sh
ssh root@172.16.0.143 'ls -la /mnt/nvme/redstone-build/output/redstone-prod-base.itb'
# md5 last verified: 77a3c0695524e4c965d506633eac7977 (v3 with i2c1 disabled, kmodloader works)
# (P3 build is in progress at time of writing — md5 will change)

# Pull local for TFTP testing
scp root@172.16.0.143:/mnt/nvme/redstone-build/output/redstone-prod-base.itb \
    images/
```

### 2. Make any change → rebuild

```sh
# Edit one of: inputs/{edgenos,dtb}/, config/p3-switch.config, files/**, scripts/*
# scp to remote (or git push then pull on remote — currently manual scp)

scp -r inputs/ config/ files/ scripts/  root@172.16.0.143:/mnt/nvme/redstone-build/
ssh root@172.16.0.143 'nohup bash /mnt/nvme/redstone-build/scripts/build-prod-base.sh \
    > /mnt/nvme/redstone-build/output/run.log 2>&1 < /dev/null & disown'

# Wait (sha-keyed cache: kernel rebuilds only if inputs/edgenos/* or inputs/dtb/* change;
#  userspace rebuilds only if config/p3-switch.config or files/** change).

# Then on Redstone serial console:
#   => tftp 0x10000000 redstone-prod-base.itb
#   => bootm 0x10000000
```

### 3. Verify boot

Expected after P3 is finished:
- OpenWrt 22.03 shell on serial
- `pgrep zebra && pgrep lldpd && pgrep snmpd && pgrep chronyd` — all running
- `uci show system | grep hostname` → `redstone-<mac-tail>`
- `ip a` → eth0 with `192.168.100.1/24`
- `redstone-info` returns the diagnostic dump (custom script in `/usr/local/bin`)

---

## Known gotchas (tripped on these in this session)

### Build / shell

- **`yes "" | make … | tail` + `set -eo pipefail` → script aborts**:
  `yes` exits 141 on SIGPIPE, pipefail tripping. Wrap `set +o pipefail` /
  `set -o pipefail` around any such pipeline. Both `build-prod-base.sh` and
  `diy-script.sh` already have this guard — copy the pattern when adding new
  build steps.

- **WSL `wsl.exe ssh ...` long timeouts get auto-backgrounded with empty stdout**:
  see `memory/feedback_bash_foreground.md`. Always `nohup bash ... & disown`
  on the remote side for builds expected to run >120s.

- **`make target/linux/compile` alone doesn't pull new packages**: stage 2 of
  build-prod-base.sh runs full `make` (= `make world`) so adding to
  `config/p3-switch.config` actually compiles the new packages. Don't "optimize"
  back to `target/linux/compile`.

### Kernel / boot

- **vendor U-Boot overrides `/chosen/bootargs`**: anything we put in
  `inputs/dtb/redstone.dts` `chosen.bootargs` gets replaced. To force flags
  like `pci=realloc`, either:
    - `setenv bootargs "..."; saveenv` in U-Boot env, OR
    - rebuild EdgeNOS kernel with `CONFIG_CMDLINE_FORCE=y` + `CONFIG_CMDLINE="..."`.
  The dts entry is currently **decorative only** but kept for documentation.

- **PCIe always negotiates gen1 even with `max-link-speed = <2>`**: fsl-pci
  driver doesn't honor the dts prop on this kernel; need ASIC-side LTSSM
  retrain (handled by BCM SDK init in P6). Cosmetic until then.

- **`mpc-i2c ffe03000.i2c: timeout 1000000 us`** at boot is harmless: controller
  resets once on probe, then RTC + EEPROM work. Likely controller reset
  sequence quirk; chip probe race not present in vendor due to extra child
  nodes serializing init.

- **`ft_fixup_l2cache: FDT_ERR_NOTFOUND`** is harmless: U-Boot's libfdt
  diagnostic. Our dts has `phandle = <0x01>` AND `linux,phandle = <0x01>`
  on `l2-cache-controller@20000`, which both kernels accept. U-Boot's
  fixup just decorates the dtb with extra cache-* properties before kernel
  hand-off; kernel does its own L2 init regardless.

- **i2c1 (`ffe03100`) is `status = "disabled"` in our dts** because the
  thermal sensor on it (`cel,ambient1`) needs CPLD-gated power that
  EdgeNOS's `kennisis_cpld` driver supplies. P3a will port that driver +
  re-enable i2c1.

### Toolchain

- **Always use `/mnt/nvme/openwrt-2203/staging_dir/toolchain-powerpc_8540_gcc-11.2.0_musl/`**:
  even when building 5.15 / 6.12 mainline kernels we always use this single
  toolchain. Confirmed working across 5.10 / 5.15 / 6.6 / 6.12.

- **Don't try to use 23.05 / 24.10 / master OpenWrt for production**:
  those use kernel 5.15 / 6.6 / 6.12 (silent on this hw). 22.03 is pinned.

---

## Where everything lives

### Local (Windows + WSL)

```
C:\other_project\R0678\redstone-build\
├── inputs/                    immutable build inputs (committed)
│   ├── edgenos/               vendor 5.10 kernel sources + patches + defconfig + dts
│   └── dtb/                   redstone.dts (our patched) + clean-dtb-1.dts (vendor reference)
├── config/p3-switch.config    P3 package additions (43 packages)
├── files/                     P3 static rootfs overlay (frr / snmp / lldpd / uci-defaults)
├── scripts/
│   ├── build-prod-base.sh     main builder (idempotent, sha-keyed cache)
│   ├── diy-script.sh          P3 customization hook
│   └── ...                    63 ad-hoc investigation scripts (commit b43e829)
├── docs/
│   ├── ROADMAP.md             this file
│   └── uboot-tftp-boot.md     U-Boot console cheatsheet
├── README.md                  short overview
└── HANDOFF.md                 short status pointer (defers to ROADMAP.md)
```

Memory files in `C:\Users\Administrator\.claude\projects\C--other-project-R0678\memory\`
auto-load each conversation; you don't need to read them manually.

### Remote build host (`root@172.16.0.143`)

```
/mnt/nvme/
├── redstone-build/                        ← 镜像我们本地仓库（手 scp 同步）
│   ├── inputs/                            (mirror of local inputs/)
│   ├── config/, files/, scripts/          (mirror)
│   ├── output/redstone-prod-base.itb      ← FIT image（每次 build 出来的）
│   └── cache/                             ← kernel src + modules tree + 中间 artifacts
├── openwrt-2203/                          ← OpenWrt 22.03 工作树（与 redstone-build 共生）
│   ├── staging_dir/toolchain-…            ← cross gcc-11.2.0
│   ├── staging_dir/host/bin/{mkimage,dtc} ← host tools we call
│   ├── build_dir/target-…/                ← per-package build dir
│   └── bin/targets/mpc85xx/p2020/         ← stock OpenWrt outputs (we don't use these directly)
├── git/redstone-build.git                 ← bare 内部 git (origin)
├── linux-515/, linux-612/                 ← (silent kernel experiments — kept for bisect)
├── edgenos-510/                           ← (alternative EdgeNOS rebuild — superseded by build-prod-base.sh)
└── immortalwrt/                           ← (24.10.6 / kernel 6.6 baseline, not production)
```

### GitHub

- `https://github.com/fullcone/redstone-build` (public)
  - branch `baseline`: pre-today state (`3ff414e`)
  - branch `main`: today's work (`8fa8723` P1 + `b43e829` investigation chore)
  - PR #1: main → baseline (Codex review requested)

---

## Concrete next steps in priority order

### Immediate (next 1-2 sessions)

1. **Wait for P3 build** (in progress as of writing). On finish:
   - scp itb local → TFTP boot test
   - Verify `pgrep zebra lldpd snmpd chronyd` all up
   - Verify `redstone-info` runs
   - If OK, commit `config/`, `files/`, `scripts/diy-script.sh`, README/ROADMAP changes
   - Push to GitHub `main`, comment `@codex review the latest head` on PR #1
   - Mark P3 done in tasks

2. **Address codex feedback on PR #1** (when bot replies). Expect P0/P1/P2/P3 ranked findings. Each → small fix commit.

3. **P3a kennisis_cpld driver port**:
   - Find vendor driver source — likely in EdgeNOS source tree under
     `drivers/misc/kennisis_cpld.c` or similar. Look in
     `/mnt/nvme/openwrt-2203/build_dir/.../linux-5.10.221/drivers/misc/`
     or original vendor `/tmp/edgenos-files/`.
   - If proprietary: write minimal mainline-style driver that maps the
     CPLD MMIO region from dts and exposes the few power-gating bits via
     gpio-controller or platform driver.
   - dts: re-enable `i2c@3100` (`status = "okay"`), add thermal node back
     with mainline-compatible compatible (`lm75` / `tmp102` if hardware
     matches; else write a thin shim driver).

4. **P4 FRR POC** (no hardware offload yet):
   - On boot, `/etc/init.d/frr start` should already work after P3.
   - Lab: connect Redstone eth0 → Linux peer with FRR running BGP.
   - Confirm BGP session up + route exchange. CPU-forwarding bandwidth
     isn't the point; verify control plane.

### Medium term

5. **P5 GitHub Actions CI**: take `smallprogram/OpenWrtAction` workflow
   YAML as a starting template. Goal: each push to `main` auto-rebuilds
   `redstone-prod-base.itb` and uploads as a workflow artifact.

6. **P2 squashfs+overlay rootfs**: parse vendor mtd partition layout
   (already in dts: jffs2 / kernel / dtb / u-boot). Add OpenWrt
   `image/p2020.mk` Device entry for "redstone" target so we can build
   `redstone-squashfs-sysupgrade.itb`. This unlocks first-boot config
   persistence (no more re-running uci-defaults each boot).

### Long-term / heavy

7. **P6 BCM SDK package** (B6 → P6):
   - Vendor needed: OpenBCM SDK 6.5.27 source (BDE/KNET/userland CLI)
   - Wrap as an OpenWrt package with kmod for KNET, userland for `bcm.user`
   - Connect to FRR via switchdev / sai / custom dataplane plugin
   - Validate hardware-offload bandwidth (line-rate 48×1G + 4×10G is the
     real BCM56846 capability)

---

## Sanity check before signing off

- [x] HANDOFF.md / ROADMAP.md describe current state, not stale plan
- [x] All commits pushed to internal `origin` (auto via post-receive hook)
- [x] Production-relevant commits also on GitHub `main` for Codex
- [x] No uncommitted on-disk work that would surprise next session
- [x] Memory files (`memory/*.md`) reflect today's decisions
- [x] PR #1 open with `@codex review` requested
- [ ] P3 image boots & runs all services (pending build completion)
