# CO-44 on the tips of 2026-11-27: base against patched, every CI tester, every affected line

The same standard as CO-38's `../../../../CO-38-read-adv-features-hidden-instances/send-20261123/evidence/gaps-20261126/`:
one base and one patched image per tree, the new case 3 times, then all eleven testers of the Bluetooth kernel CI in
full on both sides, the cases after each hang run separately, and the list's CI run locally on the exact files.
QEMU only. The raw guest logs are kept privately (`runs.tar.gz`, SHA-256 `198702eec952af4d…`); this directory
holds the summaries. The
work area is written `<work area>`.

## Trees

| tree | commit |
|---|---|
| bluetooth-next | `f57f78086ab54f3b3122fbaeba2c842ba7bb6d00` |
| mainline, latest tag v7.4-rc4 | `b6a9fa34ce4187cb69d3c588a4bbffc31ce5db8f` |
| 7.3.6 | `1a0388846138eda9f6eb4258ff227a223afc2f52` |
| 6.18.65 | `4700e3adf3b24b39dd4929e9c6d62811ba3ccea8` |
| 6.12.119 | `e2e4b92c2b2a3ae78423cb343951cb5d2241b405` |
| 6.6.163 | `e2bb30811e063ce0db964484357973b855b06572` |
| 6.1.193 | `1ca1436ccc68275d0b43b6a730b3940fcc46b7c2` |

- The `Fixes:` commit `161510ccf91c` is in 6.1 and newer, not in 5.15 or 5.10 (`git tag --contains`).
- BlueZ is master `79162c108911` plus the package's test, which applies with no offset.
- Images: BlueZ's `doc/tester.config` with KASAN and lockdep (`*.versions`).
- The package's kernel patch applies unchanged to all seven trees (`check-apply.txt`). Its patch-id on
  bluetooth-next is `63e2170f7cdfb1da7cdae5a0a8a8ef870fdab87a`.

## Results

- **The new case, "Set Device Class - Timeout 1":** base 0 of 3, patched 3 of 3, on all seven trees. On base the
  log says "Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)".
- **Every other case:** the same verdict on both sides, on every tree and tester (`compare.txt`). In full
  mgmt-tester the patched side passes exactly one case more on each tree:

  | tree | base | patched |
  |---|---|---|
  | next | 529 | 530 |
  | main | 524 | 525 |
  | 7.3 | 518 | 519 |
  | 6.18 | 511 | 512 |
  | 6.12 | 478 | 479 |
  | 6.6 | 476 | 477 |
  | 6.1 | 469 | 470 |
- **Hangs, on both sides alike** (the same cases as on 2026-11-26):
  - l2cap-tester in "L2CAP Ext-Flowctl Server - Accept 2 Close 1" on 6.18, 6.12 and 6.6;
  - iso-tester in "ISO Broadcaster Receiver Defer Get BASE - Success" on 6.12.
- **The cases after the hangs**, one per guest on both sides (`stage-c/compare-after.txt`, lists in `lists/`): 68
  case pairs (20 l2cap on each of 6.18, 6.12 and 6.6, 8 iso on 6.12), 0 differences. The failures there are
  the same on both sides.
- **Reports:** the KASAN, lockdep, WARN and hung-task counts are identical on both sides, file by file
  (`report-scan*.txt`, `scan-diff.txt`). No report is new with the patch. Only their presence and counts were
  compared, not their contents.

## The list's CI, run locally (`bot/`)

- **BlueZ test:** every check PASS.
- **Kernel patch on bluetooth-next:**
  - **PASS:** BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup,
    TestRunner_mgmt-tester, TestRunner_mesh-tester, IncrementalBuild and SubjectPrefix. The bot's own mgmt-tester
    run gives 529/529 on both sides.
  - **FAIL until the operator signs:** CheckPatch, VerifySignedoff and GitLint, each only on the missing
    Signed-off-by. No sign-off was added here.
  - **VerifyFixes:** the first run said "Target SHA1 does not exist", because the bot's clone reached back only to
    2022-06-01 and the target is from 2021-10-29. Rerun with history from 2021-10-01
    (`bot/VerifyFixes-rerun-history-2021.log`), the target resolves, and one problem is left: "empty lines
    surround the Fixes tag". The check (`cache/action-ci-bluez/scripts/verify_fixes.sh`) looks for the Fixes line
    with an empty line on both sides. The unsigned message ends with that line, so it matches. With the operator's
    Signed-off-by directly under it, it cannot match. This is read from the script, not run, since it needs the
    signed file.
- **checkpatch.pl** `--strict --no-tree --no-signoff` on the package file: 0 errors, 1 warning, the unknown-commit
  warning that `--no-tree` gives.

## Incidents in the run, all corrected

1. The first pass missed two hangs, because the guest log lines end in a carriage return. The harness was fixed and
   the runs redone; the superseded logs are kept.
2. Stage C first ran after a cleanup had removed BlueZ's build: every guest exited 127 (a missing program). It was
   stopped, BlueZ was rebuilt, and the testers were checked to exist before the rerun.
3. The runner skips a case whose log exists, so eight of those exit-127 logs (6.18 base, after01 to after08) were
   kept rather than rerun. They were moved aside, still kept, and run again. The comparison counts a log without a
   test-runner summary, or with a missing program, as not run, never as a result.

## Proposed testing note for below `---`

```
Tested in QEMU with BlueZ's doc/tester.config plus KASAN and lockdep, and a
new mgmt-tester case, "Set Device Class - Timeout 1", sent to BlueZ
separately: its emulated controller drops Write Class of Device. Without
this patch the case gets Authentication Failed in 3 of 3 runs, and with
this patch alone it passes 3 of 3, on bluetooth-next f57f78086ab5,
v7.4-rc4, 7.3.6, 6.18.65, 6.12.119, 6.6.163 and 6.1.193. In the eleven
testers of the Bluetooth kernel CI, run in full on both sides, no other
case changed on any of these kernels, and no new KASAN, lockdep or WARN
report appeared.
```

Not run: no hardware; kernels 5.15 and 5.10 (the `Fixes:` commit is not in them).
