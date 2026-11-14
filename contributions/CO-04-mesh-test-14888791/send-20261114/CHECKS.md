# CO-04 refresh, 2026-11-14: checks

Nothing was sent. [measured] = command output, logs in `logs/` (SHA256SUMS). Bot times are UTC (host clock UTC+1).

## Trees
bluetooth-next `da3cc02587c629420603df4395179ec82955c941` (was `1081a6ef8f1e0`), bluetooth/master `3b069de8a5d688c7e8381b99d6cdb7467fcae0de`, BlueZ master `20ffd285b58facfd1f2478d159a5f941b09d5be1`.

## 1. Upstream state
- `mesh_next()`, `mesh_send_done_sync()`, `mesh_send_start_complete()`, `send_cancel()` on the tip: unchanged (`mesh_next(struct hci_dev *hdev, void *data, int err)` still the destroy callback) [measured: grep mgmt.c]. `git diff 42b8c2d729268 bluetooth-next/master -- net/bluetooth/mgmt.c` touches none of them.
- lore (`mesh_send_sync`, 2026-11-14) and patchwork (`patchwork-recent.py 2026-09-10 mesh`): no merged or posted equivalent. Still `new`: Igor Putko 14888791 (the other proposal, not used), Hui Peng 14831256 / 14831271, Jiale Yao 14864878, Cen Zhang 14880941 and 14927631, Wentao Liang 14942650 (answered by a maintainer-side reviewer with objections, 11-04). syzbot's report is not closed.
- `git apply --check` of every pending diff on tip, tip+CO-04, tip+CO-05/26, tip+both (`logs/pending-apply-check.txt`) [measured]: with CO-04, 14864878 and 14888791 do not apply (same hunks as in the old notes); 14831256 and 14927631 do not apply even to the bare tip; 14942650, 14831271, 14880941 apply.

## 2. Rebase
- Applies with `git am --3way` to bluetooth-next and to bluetooth/master [measured]. Code identical to the 10-29 patch: `scripts/change-code-compare.sh` "files IDENTICAL, patch-id IDENTICAL 265c0fa30837ba22, changed lines IDENTICAL (96 lines)".
- Applies with CO-05/26 in either order: `git diff --stat both-co05-co04 both-co04-co05` empty [measured].
- checkpatch `--strict` (`checkpatch-bare.log`): only `Missing Signed-off-by`, `153 lines checked`.
- Regenerated: `patch/0001-...patch` = format-patch with `--base=da3cc025...`, author `Iaroslav Voitovych <yaroslav.voytovych@gmail.com>`, no Signed-off-by, commit message unchanged from 10-29, notes below `---` updated (tested-on tip, counts, the new lockdep paragraph, 526 cases).

## 3. QEMU, KASAN + lockdep, 4 CPUs (images: plain = tip; co04; co05; both = CO-05/26 then CO-04; same config, built incrementally from the plain image's build directory; `images/` sha256 in logs)
Master mesh-tester = the 4dc15be8 binary of 10-29; research mesh-tester = `ab927447` (`tmp/co05-w4/bin/`, read-only), through the ASAN-quarantine wrapper; one guest at a time, interleaved by boot (`mesh-logs/<set>-<image>-<n>.log`).

| set (counts are boots per image; the 10-29 counts in brackets) | plain | co04 | co05 | both |
|---|---|---|---|---|
| master mesh-tester, 3 (3) | 8/10 | 8/10 | 8/10 | 8/10 |
| `-s power`, 12 (12) | 0 reports | 0 | 0 | 0 |
| `-s unregister`, 12 (12) | 72/72 | 72/72 | 72/72 | 72/72 |
| `-s cancel`, 5 (5) | 0/100 | 1/100 | 0/100 | 0/100 |
| `-s close`, 5 (5) | 20/20 | 20/20 | 20/20 | 20/20 |
| `-s UnregSweep`, 35 (5) | 2 lockdep reports | 0 | 2 | 0 |

- 215 of 216 pairwise verdict comparisons (plain vs each other image, same boot number, `mesh-compare.txt`) show no verdict difference. The exception: `cancel` boot 1, plain vs co04: "Mesh - PwrCmp cancel queued then off" passed on co04 (a timing sweep case, which the 10-29 dossier already noted varies).
- kernel-report-scan over all non-assert guest logs: only the four lockdep logs below [measured]. No KASAN, BUG, hung task, oops anywhere. `WARNING` count 0 on co04 and both, so the new `lockdep_assert_held()` in `mesh_next()` did not fire.
- **New on the tip: a lockdep circular report at controller removal** (`circular-count.txt`, `lockdep-base-UnregSweep-plain-17.log`): plain 2 of 35 boots (`UnregSweep-plain-17`, `-28`), co05 2 of 35 (`UnregSweep-co05-3`, `-16`), co04 0 of 35, both 0 of 35; 0 reports in every other set. All four are the same chain [measured]:
  `mesh-tester-gat/60 is trying to acquire lock: (&hdev->unregister_lock), at: hci_cmd_sync_submit+0x36/0x2b0` / `but task is already holding lock: (&hdev->cmd_sync_work_lock), at: hci_cmd_sync_clear+0xdc/0x360`; stack `hci_cmd_sync_submit <- mesh_next+0x84 <- hci_cmd_sync_clear+0x184 <- hci_unregister_dev <- vhci_release`; the opposite dependency from `set_powered -> hci_cmd_sync_submit`. The full splat is in `lockdep-base-UnregSweep-plain-17.log` (from "WARNING: possible circular locking dependency detected", line 751 on, about 100 lines). 2/35 vs 0/35 is not statistically strong on its own [inferred]; the cause is read from the code: `mesh_send_done()` queues `mesh_send_done_sync` with `mesh_next` as destroy callback, `hci_cmd_sync_clear()` runs the callback under `cmd_sync_work_lock`, and `mesh_next()` calls `hci_cmd_sync_queue()`. CO-04 removes that destroy callback.
- **CO-05 lock-assertion images** (test-only assertion in `hci_add_adv_instance()`/`hci_remove_adv_instance()`; `assert-*` logs, 2 boots): master mesh-tester `WARNING` 3 per boot on assert-base, 0 on assert-co05 and assert-both; mgmt-tester `-s Advertising`: 4 per boot on all three (the other callers, outside CO-05) [measured].
- **KCSAN**, research `-s race`, 45 boots per image (`kcsan-logs`, `kcsan-count.txt`): any KCSAN report in 4 (base), 3 (co04), 6 (co05), 7 (both) boots; reports naming advertising or mesh code: 0 in all four. The reports present are `data-race in skb_queue_tail / vhci_poll`. The 10-29 run saw adv/mesh reports on the unpatched kernel in 4 of 45 boots; this run did not reproduce them on the new tip, so it shows no before/after [measured]. "both race cases passed": 45/45 on three images, 43/45 on both.

## 4. The bot's checks (kernel, patched side; base side = the CO-38 run's base side, same tip and BlueZ commit)
Mail = the regenerated patch plus a placeholder Signed-off-by in a test copy (`mail-co04-sob`); `logs/bot-co04-k`: CheckPatch, VerifyFixes, VerifySignedoff, GitLint, SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup, TestRunner_mgmt-tester (`Total: 526, Passed: 526`), TestRunner_mesh-tester (`Total: 10, Passed: 10`), IncrementalBuild: all PASS [measured]. Base side (`CO-38/logs/bot-co38-k-full`): all PASS, mgmt/mesh testers identical. Not re-run on the base side again: same base commit, same BlueZ commit.
The 10-29 GitLint failure (89-column quoted line) does not recur: the message is unchanged since the fix.

## Not done
- No syzbot reproducer and no use-after-free reproduction (operator's decision of 10-29).
- The mesh `PwrCmp` timing sweeps were not repeated.
