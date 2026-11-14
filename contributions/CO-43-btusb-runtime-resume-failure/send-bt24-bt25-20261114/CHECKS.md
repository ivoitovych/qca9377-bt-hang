# BT-24 and BT-25 as their own series on E (2026-11-14, lane 6)

Work area `/root/exp/agent-work/lane6-btusb-20261114/` (`WA` below). Everything ran in QEMU guests (4 CPUs,
KASAN, lockdep, kmemleak) with the emulated QCA9377 13d3:3503 attached over usbip to the real btusb. Nothing
touched the host's Bluetooth. Nothing was sent.

## The patches

Base: bluetooth-next `da3cc02587c6` + E ("Bluetooth: btusb: Anchor a deferred URB under txlock", the E package
unchanged, `git am`: `04b58d680611`). On it, with no code of B2 (`BTUSB_CMD_DEFERRED`), D or A
(`grep -c CMD_DEFERRED` on the three files: 0):

| # | subject |
|---|---|
| 0001 | Bluetooth: btusb: Drop deferred URBs under txlock on a failed resume (BT-24, Fixes: 7bee549e197c) |
| 0002 | Bluetooth: btusb: Free the skb of a deferred URB that is discarded (BT-25, Fixes: 7bee549e197c, 19cfe912c37b) |

Files: `out/bt24-bt25/` (`0000-cover-letter.patch`, the two patches; author Iaroslav Voitovych, no Signed-off-by).
They apply on E alone; A is not needed (`git am` on E only). Both patches are the earlier ones minus B2's
flag lines; the only text change is one paragraph added to 0002's message (below).

## btusb_close(): does it need the txlock treatment? Decision: no

Reviewer 2: it drains the deferred anchor outside `txlock`. Source (`lx`, `net/bluetooth/hci_sync.c`):
- `hci_dev_close_sync()` flushes `tx_work` (6061), `rx_work` (6062) and `cmd_work` (6129) before
  `hci_dev_drop_last_cmd_req_and_close()`, which does `clear_bit(HCI_RUNNING)` (5868) and only then
  `hdev->close()` (5872); the same helper closes after a failed open.
- `hci_send_frame()` (`hci_core.c:3163`) frees the skb and returns -EINVAL when `HCI_RUNNING` is clear, so
  `btusb_send_frame()` and `submit_or_queue_tx_urb()` are not reached: no sender anchors a URB while close drains.
- `btusb_close()` ends with an autopm get/put, so a resume that runs at the same time takes URBs from the anchor
  with `usb_get_from_anchor()` like the drain, one owner per URB. After E, `BTUSB_SUSPENDING` is only changed under
  `txlock` and close does not touch it (B2's `BTUSB_CMD_DEFERRED` clearing, which was the other thing outside the lock,
  is not in this series).
So the only defect in close is the leak, which 0002 fixes; its message now says why no locking is needed.

## Tests: base (E only) against E + 0001 + 0002

Kernels (`WA/img/`, `.commit` files): `e-kml-dbg` = E + a debug-only commit, `ef-kml-dbg` = E + 0001 + 0002 + the
same debug commit (`harness/apply-debug.py`, never in a patch). Debug hooks, module parameters of btusb:
`bt_inject=1` the interrupt URB submission at resume fails; `bt_inject=2` the submission in `play_deferred()` fails;
`bt24_delay_ms=N` the failure path of `btusb_resume()` sleeps N ms at its `done:` label (the point after the unlocked scuttle
without 0001, before the locked scuttle with it), and a work item sends one more HCI command (Read BD_ADDR) through
`btusb_send_frame()` halfway through the sleep. **This second sender replaces B2's timing**: lane 1 found the old
reproducer needed B2 (without it the command credit returns only after the failed resume's path has ended). Here the
second sender is injected, so it does not.

Commands (`harness/gen-spec-t3.sh`, `harness/run-batch.sh`; one guest at a time, `nice`/`ionice`):
`harness/run-batch.sh harness/spec-kml-e.txt logs/summaries/kml-e.txt`, `... spec-kml-ef.txt ... kml-ef.txt`,
`... spec-matrix.txt ... matrix.txt`. Raw logs `logs/runs/` (`logs/SHA256SUMS-runs`).

"objects" = kmemleak unreferenced objects after two scans 10 s apart, all Bluetooth related (skbs and setup packets).

| scenario (3 runs each, healthy 1) | E only | E + 0001 + 0002 |
|---|---|---|
| healthy suspend/resume, one command deferred | 0 | 0 |
| injection 1: failed resume with a deferred command | 3, 3, 1 | 0, 0, 0 |
| injection 2: `play_deferred()` submission fails | 2, 1, 2 | 0, 0, 0 |
| dead device (core disconnects), then close | 5, 3, 4 | 0, 0, 0 |
| dead device, hci0 powered off 1 s after the write | 2, 2, 2 | 0, 0, 0 |
| BT-24, second sender in the window (2.5 s): anchor after the failed resume | NOT empty, NOT empty, NOT empty | empty, empty, empty |

(`logs/summaries/kml-e.txt`, `kml-ef.txt`; the bt24 lines `second sender lines: 1` and `bt24-dbg: deferred anchor ...`
are in each `k-bt24-*` log.) The FAIL verdicts of the injection runs on both kernels are the injected fault itself
(Bluetooth does not work after a failed interrupt submit; the scenario's Set Powered check fails); the leak
check is the object count.

Other emulated cases, 2 runs each (`logs/summaries/matrix.txt`), identical on both kernels:

| case | E only | E + series |
|---|---|---|
| dead device | PASS, PASS | PASS, PASS |
| device that answers after the reset-resume | PASS, PASS | PASS, PASS |
| command whose event is dropped, autosuspend first | PASS, PASS | PASS, PASS |
| same, controller wedged until reset | PASS, PASS | PASS, PASS |
| 30 healthy suspend/resume cycles | 0 failures, 0 | 0, 0 |
| hci0 powered off while resuming (BT-18) | FAIL, FAIL | FAIL, FAIL (not addressed here) |

No kernel report (BUG, WARNING, KASAN, lockdep, call trace, hung task) in any of the 103 run logs of this lane
(`grep -l` over `logs/runs/*.log`: no file).

Not covered: the cleanup loop at the end of `play_deferred()` (needs two deferred URBs).

## checkpatch `--strict --no-tree` (this tree's script, run directly)

Both patches: only `ERROR: Missing Signed-off-by: line(s)`, `total: 1 errors, 0 warnings, 0 checks`.

## Bot CI

See the end of this file (appended after the run).

### Bot CI (run locally, dry run, harness/run-bot.sh; results out/bot-results/bt24/)

The project's scripts/bot-ci-local.sh (lane 1's copy with its local changes, plus --cpu-shares 256, nice inside the
container and 4 CPUs), the bot's code at 60348956fc7b (image bluez-action-ci:60348956fc7b), base = E (04b58d680611),
BlueZ 20ffd285b58f. Patched side: CheckPatch, VerifySignedoff and GitLint FAIL (each only the missing Signed-off-by);
VerifyFixes FAIL ("Target SHA should be an ancestor of your tree": the project's partial kernel history, as in earlier
packages); SubjectPrefix, BuildKernel, CheckAllWarning, CheckSparse, BuildKernel32, CheckKernelLLVM, TestRunnerSetup and
IncrementalBuild PASS. Base side: the six tree checks PASS. No tester is selected for a btusb-only change.
