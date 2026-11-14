# Task 2: D's system path (D v2), B2's message and the series, BT-24 and BT-25 (2026-11-14)

QEMU guests (4 CPUs, KASAN, lockdep; kmemleak for step 3), emulated QCA9377 13d3:3503 against real btusb.
Nothing touched the host's Bluetooth. Nothing was sent. Raw logs `logs/runs/` (`logs/SHA256SUMS`), batch
summaries `logs/summary-*.txt`, `logs/metrics.txt` (metrics.py over every log; no BUG/WARNING/KASAN/lockdep/
hung-task/Call Trace line in any of the 59 run logs). Harness: `harness/` (task 1's with `--expect-no-leak`,
`--inject`, the `bt24` scenario). Kernel tree `../lx` (branches below), images `../img/` with `.commit` records.

## 1. D v2: a resume-side discriminator (`patches/series/0003-...Recover-after-a-runtime-reset-resume.patch`)

Chosen: `udev->dev.power.runtime_status == RPM_RESUMING` (helper `btusb_runtime_resuming()`, `#ifdef CONFIG_PM`
because the field exists only then). The recorded `suspend_auto` of v1 is gone: it recorded the kind of suspend,
and a device already runtime-suspended at system sleep keeps it.

Why the source supports it (bluetooth-next `da3cc02587c6`; the files below are unchanged between it and my tree):
- Runtime resume: `rpm_resume()` sets `RPM_RESUMING` at `drivers/base/power/runtime.c:935`, then calls the
  runtime_resume callback at `:940`; for USB that is `usb_runtime_resume()` -> `usb_resume_both(udev,
  PMSG_AUTO_RESUME)` (`drivers/usb/core/driver.c:2022-2031`), which reaches `driver->reset_resume()` through
  `usb_resume_interface()` (`driver.c:1581`, `:1369`). The callback therefore sees `RPM_RESUMING`.
- System resume: `usb_resume()` (`driver.c:1660-1686`, "The device lock is held by the PM core") calls
  `usb_resume_both()` first and only afterwards `pm_runtime_disable(); pm_runtime_set_active();
  pm_runtime_enable()` (`:1672-1676`). No `rpm_resume()` runs for the device, so its status is `RPM_SUSPENDED`
  (it was runtime-suspended) or `RPM_ACTIVE` (it was not) inside the callback. Runtime PM is also disabled for the
  device from `device_suspend()` (`drivers/base/power/main.c:1748`, "any runtime PM operations targeting the device
  will fail") until `device_resume_early()` re-enables it (`:1027`).
- A device already runtime-suspended at system sleep: `usb_suspend_both()` returns at once for a suspended device
  (`driver.c:1425-1427`), `btusb_suspend()` does not run, and at the system resume the status is `RPM_SUSPENDED`
  -> no reset is queued. This was the hole in v1.

Limits (stated, not tested): the system path cannot be run (`vhci_hcd` refuses system suspend, raw-gadget cannot
resume). Reading the source I cannot exclude a runtime resume racing with the system-resume callback after
`device_resume_early()` re-enabled runtime PM; the USB core has the same exposure. The field is read directly
(no accessor exists; `drivers/gpu/drm/xe/xe_pm.c` and `drivers/pmdomain/core.c` compare it too). Without
CONFIG_PM the helper returns false.

Runtime matrix on `ab2dv2` (A + B2 + D v2; `harness/gen-spec.sh ... ab2dv2 1 3 v`,
`logs/summary-dv2-matrix.txt`, command `harness/run-batch.sh`): **18/18 PASS**: dead device, recovering device,
power-off-started resume, dropcmd, dropcmd-wedge, 30 healthy cycles, three runs each. Spot values: dead device
credit back after 0.001 s with 3 timeouts, recovering device two USB resets and a rebinding.
Delayed-reset test (debug-only usbcore delay 3 s, autosuspend 500 ms, `--expect-rebind`, kernel `ab2dv2-dbg`,
`logs/summary-dv2-delay.txt`): **3/3 PASS** (two USB resets, hci0 removed and back, class write 0x00).
Wording as asked: for the earlier wide D the delayed runs failed 0/3 in task 1 in the sense that the reset and the
rebinding were lost, while the final class write still returned 0x00 and Bluetooth worked.

## 2. B2's message, the series, checkpatch

B2 now says what it does and what it needs: the second reset that used to rebind btusb came from btusb_reset(),
not from the core (btusb has no reset_resume, the core does not rebind after a runtime resume); each queued
command now times out on its own about 2 s apart; it depends on D ("Recover after a runtime reset-resume"; 0/3
recovered with B2 alone). The cover letter states the dependency and the emulation figures (all from task 1 and
this task's runs; "5.38 s then 0.001 s" is `base-a-dead-1` against `ab2d-a-dead-1`).

Series (no Signed-off-by) in `patches/series/`: 0000 cover letter, 0001 A (the send package's text, unchanged),
0002 B2, 0003 D v2, on `da3cc0258`. Tested kernels carried A in its earlier comment wording; the only difference
between the tested tree (`lane1-d-v2`) and the series (`lane1-final`) is that comment (`git diff` shows one
comment hunk). checkpatch `--strict --no-tree` on 0001-0003: only `Missing Signed-off-by`.
**B2 does not apply on top of E** (`git cherry-pick` conflicts in `submit_or_queue_tx_urb()`, where both change the
same lines): if E is merged first, B2 needs a rebase, trivial but not done here.

## 3. BT-24 and BT-25, on top of E (`patches/on-E/`)

- `0001` BT-24: `btusb_resume()`'s failure and `done` labels merged; the scuttle and the clearing of
  `BTUSB_SUSPENDING` happen in one `txlock` section, only when an error is returned. Fixes: 7bee549e197c.
- `0002` BT-25: new `btusb_free_deferred_urb()` / `btusb_discard_deferred()` free setup packet and skb with the URB
  (`dev_kfree_skb_any()`: two sites run under `txlock` with interrupts off); used by `btusb_close()`, the failure
  path, and both discard sites of `play_deferred()`. Fixes: 7bee549e197c, 19cfe912c37b.
- checkpatch `--strict --no-tree`: Missing Signed-off-by, and the unknown-commit-id warning for the Fixes tags
  (`--no-tree`; both titles verified in the history: 7bee549e197c "Bluetooth: Add USB autosuspend support to btusb
  driver", 19cfe912c37b "Bluetooth: btusb: Fix memory leak in play_deferred").
- Not covered by a reproduction: the cleanup loop in `play_deferred()` (it needs two deferred URBs; one command
  is sent at a time, so commands alone never reach it). Source-reasoned, same fix as the other three sites.

### BT-25 (kmemleak): kernels `e-kml-dbg` (E + debug injection) against `ef-kml-dbg` (E + 0001 + 0002 + the same injection)

Injection (debug-only module parameter `bt_inject`): 1 = the interrupt URB submission at resume fails (reaches the
failure scuttle with a command deferred); 2 = `play_deferred()`'s `usb_submit_urb()` fails (its submit-failure
branch). Commands: `harness/gen-spec-t3.sh harness/spec-t3-e.txt e-kml-dbg` and `... spec-t3-ef.txt ef-kml-dbg`,
`harness/run-batch.sh`; `logs/summary-t3-e.txt`, `logs/summary-t3-ef.txt`. "objects" = kmemleak unreferenced objects
after two scans (the harness's earlier method).

| scenario (3 runs each, healthy 1) | E only: objects per run | E + fixes: objects per run |
|---|---|---|
| healthy control | 0 | 0 |
| injection 1, failed resume with a deferred command | 2, 1, 1 | 0, 0, 0 |
| injection 2, `play_deferred()` submit fails | 1, 2, 0 | 0, 0, 0 |
| dead device (core disconnects), then close | 4, 3, 2 | 0, 0, 0 |
| dead device, hci0 powered off 1 s after the write | 1, 1, 3 | 0, 0, 0 |

All objects on E-only were Bluetooth-related (setup packets and skbs); injection 2 leaked in 2 of 3 runs (kmemleak
reports an object only once it is old enough, so a 0 there is not proof; the E+fixes 0s are over all 12 runs).
The `FAIL` verdicts on the injection runs (both kernels) are the injected fault itself: after a failed interrupt
submit Bluetooth no longer works and the scenario's own check of Set Powered off fails; the leak check is the
object count.

### BT-24: reproduced only on a tree with B2

On the E tree it cannot be reached (`e-kml-dbg`, `k-bt24-*`: the second sender found the anchor empty, 3/3): without
B2 the command credit comes back only after `btusb_reset()` returns, which is after the failed resume's path has
ended, so no second URB is sent in the window (BT-19's block hides BT-24). With B2 the credit is back at once.
Kernels `bb-dbg` (A + B2 + D v2 + injection, no fix) against `bf1-dbg` (the same with the 0001 shape of the fix);
debug delay 2.5 s (`bt24_delay_ms`) after the scuttle in `bb-dbg`, before the locked section in `bf1-dbg` (the fix
has no window to widen); a first class write is deferred and its resume fails (`bt_inject=1`), a second is sent after
the first has timed out, the kernel then prints `bt24-dbg: deferred anchor empty|NOT empty` (debug-only line).
`logs/summary-bt24-b2tree.txt`:

| kernel | anchor after the failed resume, 3 runs |
|---|---|
| `bb-dbg` (no fix) | NOT empty, NOT empty, NOT empty: the URB is parked on an active device |
| `bf1-dbg` (fix) | empty, empty, empty |

Both kernels show the second command timing out (0x05): with the fix the URB sent in the window is dropped with the
others instead of staying parked, so what the fix changes is that nothing stays parked for the next resume, not that
the command is answered. The fix was applied to the A,B2,D-v2 tree by hand for this test (the 0001 patch itself is
on E); both have the same hunk shape. The BT-24 test places the delay differently in the two kernels by necessity.

## Open

- System path of D: source reading only; no run possible on this harness.
- B2 on top of E needs a rebase (conflict above).
- `0002` cleanup loop in `play_deferred()` not exercised; BT-24's harm on a real device is a parked command that times
  out, as reviewer 7 described; the emulator shows the parked URB, not a user-visible failure.
- Whether the dropped commands should be reported to the HCI layer (BT-25 note in `docs/issues.md`) is not
  addressed: the patches only free memory.
- Branches in `../lx`: `lane1-final` (series), `lane1-d-v2`, `lane1-ef` (E + 0001 + 0002), `lane1-e`, and the
  debug branches `lane1-e-dbg`, `lane1-ef-dbg`, `lane1-bb-dbg`, `lane1-bf1-dbg`, `lane1-d-v2-dbg`.
