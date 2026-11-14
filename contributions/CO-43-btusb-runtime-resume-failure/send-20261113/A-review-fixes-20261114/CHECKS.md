# CO-43 A, revised (2026-11-14, lane 6)

`WA` = `/root/exp/agent-work/lane6-btusb-20261114/`. Patch: `WA/out/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch`
on bluetooth-next `da3cc02587c6` (applies with `git apply --check`; branch `l6-a` in `WA/lx3`). Author Iaroslav
Voitovych, no Signed-off-by. Nothing sent.

## Changes against send-20261113/A

1. **Order of events.** The old message said the command times out two seconds after the error. The package's own
   table had the command at 9.378 s, `tx timeout` at 11.412 s and the new line at 16.533 s. The message now uses
   reviewer 7's wording: "An HCI command deferred during the resume can time out while the waker is still waiting,
   since the command timer is already running. Report the runtime-resume error when the PM request returns, so that the
   command timeout can be correlated with the failed resume." It also no longer says the URB stays on the anchor.
2. **`bt_dev_err_ratelimited()`** for the line (the message says why: the waker runs once per deferred send).
3. The test note after `---` now gives the order seen in the new run.

## Emulator, base against patched (`harness/spec-a.txt`, `harness/run-batch.sh`)

Kernels (kmemleak/KASAN/lockdep config): `base-kml` = `da3cc02587c6`, `a-new` = base + this patch (`img/*.commit`).
Scenario `bt17 --fail-at 1`: the emulated QCA9377 autosuspends, MGMT Set Device Class starts a resume whose GET_STATUS
is never answered, the device is dead afterwards.

| kernel | runs | "Failed to resume device for deferred data" lines | `tx timeout` |
|---|---|---|---|
| base-kml | 1 | 0 | 1 |
| a-new | 2 | 2 per run, both -16 | 1 per run |

`a-new-a-dead-1.log`: `[10.088893] hci0: command 0x0c24 tx timeout`, then `[15.237618]` and `[15.238739]`
`hci0: Failed to resume device for deferred data: -16`. Both kernels: scenario result identical (hci0 removed, class write
status 0x05). The line still appears with `bt_dev_err_ratelimited()`; the first of a burst is never suppressed.
Logs: `logs/runs/base-kml-a-dead-1.log`, `a-new-a-dead-{1,2}.log`, summary `logs/summaries/a.txt`.

## checkpatch `--strict --no-tree`

`ERROR: Missing Signed-off-by: line(s)`, `total: 1 errors, 0 warnings, 0 checks, 14 lines checked`.

## Bot CI

See the end of this file (appended after the run).

### Bot CI (run locally, out/bot-results/a/)

Same setup as the BT-24/25 package, base da3cc02587c6. Patched: CheckPatch and VerifySignedoff FAIL (only the missing
Signed-off-by); VerifyFixes PASS (no Fixes tag); SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32,
CheckKernelLLVM, TestRunnerSetup, IncrementalBuild PASS. GitLint FAIL: the missing Signed-off-by and "B1 Line exceeds max
length (98>80)" in the test note after the "---"; the note was rewrapped afterwards (no line of the mail outside the diff
is over 80 characters now, checked with awk); the bot was not rerun. Base: the six tree checks PASS.
