# Redstone (R0768-F0002-00) — Handoff

> Last update: 2026-05-03. Two-line cold-start; full plan lives in
> [`docs/ROADMAP.md`](docs/ROADMAP.md).

## TL;DR

- **P1 ✅** — `scripts/build-prod-base.sh` produces `output/redstone-prod-base.itb`
  (OpenWrt 22.03 + EdgeNOS 5.10.224 + patched dtb), boot-verified.
- **P3 in progress** — `scripts/diy-script.sh` adds 43 switch packages
  (frr, lldpd, snmpd, chrony, mstpd, collectd, ...) + first-boot config.
- **PR #1** open, `@codex review` requested:
  https://github.com/fullcone/redstone-build/pull/1

## Where to read

| Document                           | Purpose                                       |
|------------------------------------|-----------------------------------------------|
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | full forward plan, gotchas, where everything lives |
| [`README.md`](README.md)           | layout + build invocation                     |
| [`docs/uboot-tftp-boot.md`](docs/uboot-tftp-boot.md) | U-Boot console cheatsheet         |
| `memory/*.md` (~/.claude/...)      | auto-loaded context (kernel regression, kexec findings, board name, paths) |

## When you wake up

```sh
# 1. status
cd C:/other_project/R0678/redstone-build
git status && git log --oneline -5
gh pr view 1 --repo fullcone/redstone-build  # check codex feedback

# 2. latest image (if P3 build finished while you slept)
ssh root@172.16.0.143 'ls -la /mnt/nvme/redstone-build/output/'
scp root@172.16.0.143:/mnt/nvme/redstone-build/output/redstone-prod-base.itb images/

# 3. boot test
# uboot> tftp 0x10000000 redstone-prod-base.itb
# uboot> bootm 0x10000000
```

If P3 build failed, see `output/BUILD.log` on remote and `docs/ROADMAP.md`
section "Known gotchas".
