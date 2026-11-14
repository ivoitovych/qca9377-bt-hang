# CO-05 + CO-26 refresh, 2026-11-14: checks

Nothing was sent. [measured] = command output, logs in `logs/`. Bot times are UTC (host UTC+1). The guest runs, images and the lockdep finding are shared with CO-04: see `../CO-04/CHECKS.md` for the full tables; this file gives what is specific to CO-05/26.

## Trees
bluetooth-next `da3cc02587c629420603df4395179ec82955c941` (was `1081a6ef8f1e0`), bluetooth/master `3b069de8a5d688c7e8381b99d6cdb7467fcae0de`, BlueZ `20ffd285b58facfd1f2478d159a5f941b09d5be1`.

## 1. Upstream state
- `mesh_send_sync()` on the tip: still adds the instance without `hdev->lock` and has the `err` carry-on (patches apply with unchanged context) [measured]. Not superseded.
- **Cen Zhang 14927631** ("hci_sync: Fix remaining advertising instance UAFs", still `new`) takes the same lock in `mesh_send_sync()` plus many `hci_sync.c` functions. It no longer applies to the bare bluetooth-next tip (`hci_sync.c:2077`), so it will be respun; Luiz replied on 11-02 (quoted: he "sort of agree[s]" with a netdev-ai review finding and would rather avoid the allocation it adds). With CO-05 applied its `mgmt.c` hunk also fails (`mgmt.c:2375`). If it lands, CO-05 1/2 is redundant. (`logs/pending-apply-check.txt`, `pw-14927631.diff` in the work area.) The same patch's `hci_sync.c` part also changes the extended-advertising duration code, which CO-12 touches [measured: read].
- Cen Zhang's other patch 14927632 "Initialize advertising RPA work only once" was accepted and is on the tip (no overlap with our hunks).
- Wentao Liang 14942650 (mesh_send failure path) applies with CO-05; Hui Peng 14831256 does not apply to the tip.

## 2. Rebase
- Both patches apply with `git am --3way` on bluetooth-next and bluetooth/master [measured]; code unchanged from 10-29 (applied from the old mails, `git am` clean, no conflict). The two orders with CO-04 give identical trees (`git diff --stat` empty).
- checkpatch `--strict` (`checkpatch-bare.log`): 1/2 `21 lines checked`, 2/2 `31 lines checked`, only `Missing Signed-off-by` each.
- Regenerated `patch/0001`, `0002` (format-patch `--base=da3cc025...`, real author, no Signed-off-by) and a new cover letter `patch/0000-cover-letter.patch` (updated tested-on paragraph; it also mentions 14927631 as a fact).

## 3. QEMU (same images and boots as CO-04; 3 extra images with a test-only module parameter)
- master mesh-tester, 3 runs per image: 8/10 on plain, co05, both [measured].
- Lock-assertion images (2 boots each): master mesh-tester `WARNING` 3 per boot on assert-base (all from `mesh_send_sync()`), 0 on assert-co05 and assert-both; `mgmt-tester -s Advertising` (125 cases, 124 pass) 4 warnings per boot on all three (the other callers named in the 10-29 dossier; outside this series) [measured].
- **CO-26 fault injection** (`inject-summary.txt`; first mesh add fails with -ENOMEM through `bluetooth.scratch_fail_mesh_add`, kprobe trace, master mesh-tester `-s Send`, 2 boots per image): base: `hci_add_adv_instance` -> -12, `hci_schedule_adv_instance_sync(instance 6)` -> -2, `mesh_send_sync` -> -2, `mesh_send_start_complete(err=-2)`; co05 and both: `hci_add_adv_instance` -> -12, `mesh_send_sync` -> -12, `mesh_send_start_complete(err=-12)`, no schedule call. Tester `Total: 5, Passed: 2` on all six runs [measured]. As on 10-29.
- KCSAN, 45 boots per image: no report naming advertising or mesh code on any image (base included), so no before/after this time (CO-04 file for counts).
- Not changed by the series: the controller-removal lockdep cycle (plain 2/35, co05 2/35); it is the CO-04 finding.

## 4. The bot's checks (kernel, patched side; base from the CO-38 run: same tip and BlueZ commit)
Test copies with a placeholder Signed-off-by (`mail-co05-sob`); `logs/bot-co05-k`: CheckPatch, VerifyFixes, VerifySignedoff, GitLint, SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup, TestRunner_mgmt-tester (`Total: 526, Passed: 526`), TestRunner_mesh-tester (`Total: 10, Passed: 10`), IncrementalBuild: all PASS; VerifyFixes passes with `--history-since 2022-06-01` (on 10-29 it failed only for the shallow history) [measured].

## Not done
- No kernel build of the combination with the CO-12 clamp.
- The 10-29 "mgmt-tester one at a time" run was not repeated (the bot's whole-suite run, 526 cases, passes).
