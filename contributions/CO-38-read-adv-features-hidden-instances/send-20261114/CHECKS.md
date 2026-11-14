# CO-38 refresh, 2026-11-14: checks

Nothing was sent. Marks: [measured] output of a command, logs in `logs/` (SHA256SUMS), [quoted], [inferred].
Times in the bot summaries are UTC; the host's clock is UTC+1 (progress.log, 2026-11-14 02:17 to 05:04 local).

## Trees [measured: git log of the fetched refs]
- bluetooth-next master `da3cc02587c629420603df4395179ec82955c941` (2026-11-12 14:37 -0500, "Bluetooth: hci_vhci: Report write readiness with queued input"). The old package was on `42b8c2d729268`.
- bluetooth master `3b069de8a5d688c7e8381b99d6cdb7467fcae0de` (2026-11-12, "Bluetooth: L2CAP: Fix size check for receive buffer space").
- BlueZ master `20ffd285b58facfd1f2478d159a5f941b09d5be1` (2026-11-12, "shared/gatt-client: Track pending discovery Database Hash reads"). Old: `14bd6ab65f4a`.

## 1. Upstream state
- Kernel: `git diff -U0 42b8c2d729268 bluetooth-next/master -- net/bluetooth/mgmt.c` [measured]: four hunks (HDT settings, stop_discovery_complete); none in `read_adv_features()`. `adv_instance->instance <= hdev->adv_instance_cnt` is still at `mgmt.c:8892` of the tip [measured: grep]. Not superseded.
- lore search (`s:"Read Advertising Features"`, `adv_instance_cnt le_num_of_adv_sets`, 2026-11-14): nothing newer than 2023 and nothing about this bug [measured, `logs` not kept: atom files in `/root/exp/agent-work/lane3-mgmt-20261114/CO-38/lore-search-*.xml`].
- patchwork since 2026-10-28 (`scripts/patchwork-recent.py`): no patch on this. Nearest: Piyus Kedia 14976301 "mgmt: drop advertising instances the controller cannot carry" (other bug, `pw-14976301.txt`); Weihong Guan BlueZ 14974678/14974679 (emulator advertising-set count, "single advertising set tests"; new, not merged; may conflict textually with our `mgmt-tester.c` additions) [measured].
- CO-12 duration fix (the BlueZ series' 8 expected failures): the tip's `hci_enable_ext_advertising_sync()` still has `u16 duration = adv->mesh ? adv->timeout : adv->timeout * MSEC_PER_SEC;` [measured: grep hci_sync.c:1747]. Not fixed upstream.

## 2. Rebase and regeneration
- Kernel: `git apply --check` of the old patch on bluetooth-next and on bluetooth/master: applies [measured]. Regenerated with `git format-patch -1 --base=da3cc025...`: `patch/0001-...patch`. Code identical to the old diff (one line); no Signed-off-by (operator adds); author line `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>` as in the old package. A copy made on bluetooth/master: `patch-btmaster/` (placeholder author, test copy).
- checkpatch `--strict` (`logs`: `checkpatch-next.log`, `checkpatch-btmaster.log`): `total: 1 errors, 0 warnings, 0 checks, 8 lines checked`, the one error `Missing Signed-off-by` [measured]. Fixes tag resolves.
- BlueZ: the three old patches applied with `git am --3way` on `20ffd285b58f`: one conflict in `tools/mgmt-tester.c` (both sides append a block before `main()`: the HDT tests and ours), resolved by keeping both. `git range-diff old..new`: patches 2 and 3 unchanged, patch 1 changed only in the context lines of that hunk [measured]. Diffstat 558 insertions (32 + 526), as before. Cover letter regenerated with the new tips (`patch/bluez/0000-cover-letter.patch`); the claims in it are the measurements below. No Signed-off-by (BlueZ takes none).
- Subject widths unchanged: 51, 56 and 57 columns (decision D9 of 11-02 still open).

## 3. QEMU (KASAN + lockdep, 4 CPUs, 2 GB; test-runner, tester binaries from the regenerated series HEAD)
Kernels: plain = bluetooth-next `da3cc02587c6` (bzImage sha256 `32ef4682e250...`), fix = plain + the patch (`a2a9e731ecd5...`); config = the 11-02 config (doc/tester.config + SMP/kprobe fragment + KASAN + lockdep). The CO-12 clamp is in neither. Commands `mgmt-tester-series -p Add` (128 cases) and `mesh-tester-series -p Mesh` (10), 3 runs each (`logs/mgmt-*`, `logs/mesh-*`, `logs/compare-all.txt`) [measured].

| | plain | fix |
|---|---|---|
| mgmt-tester "Add", 3 runs | Passed 119, Failed 9 (identical sets) | Passed 120, Failed 8 (identical sets) |
| mesh-tester, 3 runs | 8/10 ("Send cancel - 1" and "- 2" fail) | 8/10, the same |

- The only case whose verdict changes: "Add Ext Advertising - Instance 2 listed alone", Failed 3/3 to Passed 3/3. The 8 duration cases fail on both (need CO-12) [measured: compare-tester-verdicts.py]. Same as the 11-02 result.
- kernel-report-scan over the 12 guest logs: all clean [measured].

## 4. The bot's checks (`scripts/bot-ci-local.sh`, image bluez-action-ci:60348956fc7b)
Run from my clone of the project. The kernel mail used for the full run is the regenerated patch with a placeholder `Signed-off-by: Iaroslav Voitovych <author@example.com>` added (as run, the domain was `example.invalid`) (test copy `project/tmp/mail-co38-sob/`; never for sending), because the S-o-b dependent checks otherwise fail for that reason alone.
- Without any S-o-b (`logs/bot-co38-k-msg2`): CheckPatch FAIL (Missing Signed-off-by only), VerifySignedoff FAIL, GitLint FAIL (CC1 no Signed-off-by), VerifyFixes FAIL ("empty lines surround the Fixes tag": that tag is the last line of the message), SubjectPrefix PASS [measured].
- With the placeholder S-o-b, kernel, both sides, `--history-since 2022-06-01` (`logs/bot-co38-k-full`, ALL DONE, exit 0):
  patched: CheckPatch, VerifyFixes, VerifySignedoff, GitLint, SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup, TestRunner_mgmt-tester, TestRunner_mesh-tester, IncrementalBuild: all PASS. base: BuildKernel ... TestRunner_mesh-tester: all PASS. Tester pairs: "not-passed sets identical: True (A 0, B 0)" for both; kernel-report-scan exit 0 [measured].
- BlueZ (`--space user`, 3 patches, `logs/bot-co38-bluez`, both sides; kernel image = the plain image):
  patched: CheckPatch PASS, GitLint PASS, BuildEll PASS, BluezMake PASS, CheckSmatch PASS, bluezmakeextell PASS, ScanBuild PASS, **TestFunctional FAIL** (`test_bap.py::test_bass_past_transport_acquire[hosts9-vm2]`: "Failed to acquire: org.bluez.Error.Failed"), IncrementalBuild FAIL "Failed to reset to base commit" (the local setup defect of 11-02: the shared clone's alternates path is not mounted in the container).
  base: BuildEll, BluezMake, CheckSmatch, bluezmakeextell, TestFunctional PASS; ScanBuild FAIL (same setup defect on the base side; the bot's ScanBuild does not check out the base anyway).
  Re-runs on a tree without alternates (repacked clone; `logs/bot-co38-bluez-rerun`, `-rerun2`): patched `IncrementalBuild` PASS (843 s). patched `TestFunctional`: FAIL in rerun 1 (`test_bap.py::test_bass_past_earbuds_transport_acquire[hosts11-vm3]`, "Failed to acquire: org.bluez.Error.Failed", a different BAP test than the first failure), PASS in rerun 2; base `TestFunctional` PASS in both bot runs. So patched: 2 FAIL (different BAP tests) of 3, base: 0 of 2 [measured]. Judged a flaky BAP/BASS test under a heavily loaded host (load average 20 to 30 during these runs) and unrelated to the series [inferred]; not proven, the failing runs are in the logs. ScanBuild base side still FAILs on the first run for the setup defect only.
  The series changes only `tools/mgmt-tester.c` and `tools/mesh-tester.c`, which that test does not use [inferred]; the unrelated flake of 11-02 was `test_bluetoothctl_pair_bredr`.

## Surprises
- The kernel fix compiled without change; nothing in the touched function moved.
