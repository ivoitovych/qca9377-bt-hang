# One Ubuntu 24.04 bluez update for all our 5.72 fixes: `5.72-0ubuntu5.9` (2026-11-14; nothing filed)

Four dossiers had each prepared a 5.72 change, partly under the same proposed version. This folder
is the one upload that carries all of them, on top of Ubuntu's current `5.72-0ubuntu5.8` (still
the newest in noble-updates and noble-security, nothing in noble-proposed, Launchpad 2026-11-14
03:12 UTC). The operator files the bugs and finds a sponsor; nothing here was filed or uploaded.

| quilt patches | fixes | dossier | origin |
|---|---|---|---|
| 1-2 | btmon aborts on long lines | CO-11a | upstream `fdbfe0018f6f`, `dca0f10fd560` |
| 3 | U24, use-after-free at exit while discovering | CO-37 | upstream `7e3212fa233e` (in 5.88) |
| 4-6 | U23, use-after-frees at exit with a streaming sound server | CO-37 | 4: partial upstream backport; 5-6: written for this update, not upstream |
| 7-9 | U12, A2DP lost when an application opens the microphone | CO-03 | upstream `a14d59725`, `664a5d3785a1` and a companion |
| 10 | "refused" instead of "unknown" for a refused connection | CO-40 | upstream `a6ac17f0e393` |

- `deliver/bluez_5.72-0ubuntu5.8_5.72-0ubuntu5.9.debdiff` — the upload as a debdiff (12 files: the
  changelog, the series and the ten patches); `patches/` — the ten patches with DEP-3 headers;
  `changelog-entry.txt`; `bugs/` — one Launchpad description per issue (`LP-…` placeholders);
  `BUNDLE.md` — which bugs it closes, the SRU test plan, the open points; `CHECKS.md` — every build
  and test with its command and result; `bin/` — the scripts.
- **Tested** (QEMU guests and noble containers, emulated controllers; nothing on the laptop),
  base 5.8 vs this bundle: U12 trigger 70/70 lost → 0/70; installed `.deb`s T201 lost 3/3 → kept
  3/3; U12 harness 27/35 → 35/35; btmon replay aborts in 32 of 72 cells → 0, live 20 of 60 → 0;
  U23 ASan exit 10/10 → 0/10; U24 10/10 → 0/10; refused-vs-unknown `unknown` 10/10 → `refused`
  10/10. BlueZ's unit tests 30 of 32 on both (the same two fail). Builds exit 0 on both.

**Checked on copy (2026-11-14):** the U12 harness summaries (`pass=27 fail=8` base, `pass=35
fail=0` bundle) and the btmon live table (20 runs exit 134, all on base; none of the 60 bundle
runs). The live job's guest log ends in a kernel stack trace printed after all 120 result rows,
at the guest's exit; it was not analysed.

**Changed on copy:** the three written-for-this-update patches' DEP-3 `Author:` and the changelog
trailer give the operator's own address (the work area had a placeholder); the debdiff carries the
same lines. Left in the work area
(`/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle/`): the built `.deb`s and
`.debian.tar.xz`, the `.dsc`, Ubuntu's full `debian/` tree and the build logs (Ubuntu's and
Debian's own changelog and maintainer history), and the raw run folders (guest output, 145 MB).

**Found on the way** (`BUNDLE.md`): Ubuntu uploaded `5.85-4ubuntu0.5` (resolute) and
`5.87-4ubuntu0.1` (stonking) to proposed on 2026-11-10 for an unrelated bug, the versions CO-11a's
btmon debdiffs for those series proposed, so those need renumbering; tenacious is at `5.88-1`,
which makes CO-11a's tenacious debdiff obsolete; tenacious lists a btmon CVE (CVE-2026-105460)
not yet checked against 5.72.
