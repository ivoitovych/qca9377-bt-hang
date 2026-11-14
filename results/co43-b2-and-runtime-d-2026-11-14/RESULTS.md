# Task 1: B replacement (B2) and D narrowed, on a fixed harness (2026-11-14)

Everything ran in QEMU guests (4 CPUs, KASAN, lockdep) with the emulated QCA9377 13d3:3503 against real
btusb. Nothing touched the host's Bluetooth. Nothing was sent. All raw logs are in `logs/runs/`
(`SHA256SUMS` in `logs/`); per-run summaries `logs/summary-*.txt`; `logs/metrics.txt` is
`harness/metrics.py` over every log. Kernel reports (BUG, WARNING, KASAN, lockdep, hung task) in all
86 run logs: none (measured, `grep -v kreports=0 logs/metrics.txt` is empty).

Layout: `harness/` (copy with the fixes), `patches/` (format-patch, no Signed-off-by), `logs/`.
Kernel trees: `/root/exp/agent-work/lane1-btusb-20261114/lx` (built with `harness/build-kernel.sh`),
images in `../img/` with `.commit` records. Images `base`, `b2`, `ab2d` are the existing ones from
`/root/exp/agent-work/bt17-emu-20261113/img/` (sha256 of the image is the second line of each run log).

## 1. Harness fixes (reviewer 7)

| fix | change | break it, watch it fail, restore |
|---|---|---|
| `--recover` on a reset, not on unlink | after the unlink the device is `lost` (every control transfer -71). The first device-descriptor read (the USB core reads it only after resetting the port; vhci never forwards the reset) recovers it and drops its queued event bytes | break `--mutate-no-reset` (reset ignored): base FAIL, `base-st1-noreset-1` and `base-st1-noreset-1.log.first-batch-stdin-eaten`. Restored: `base-f1-recover-1` PASS, `EMU reset seen` line |
| `recover` judged by a command round trip | success = hci0 back, power-on 0 and class write 0x00 (already in the earlier hardened harness); `--expect-rebind` added (hci0 must be removed after the recovery) | break `--mutate-legacy-judge` ("hci0 reappeared"): `b2-st2-legacyjudge-1` wrongly PASS while class write = 0x05. Restored: `b2-st2-judge-1` FAIL |
| a failed case fails the run | emulator prints `PASS/FAIL <scenario>`, exits non-zero for anything but True, also for an exception, an unknown scenario, a failed bring-up; `run-guest.sh` exit 0/1/3 and a `PASS/FAIL` line; `run-batch.sh` exits 1 if any run failed | break `--mutate-swallow`: `b2-st3-swallow-1` wrongly PASS exit 0. Restored: `base-st3-raise-1`, `base-st3-unknown-1` FAIL exit 1 (the batch exited 1) |

Command: `harness/run-batch.sh harness/spec-selftest.txt logs/summary-selftest.txt`.
Not done: a reset that clears the controller's state (reviewer finding 16); the emulator still always
reports patch and NVM loaded.

A harness bug found on the way (inferred, consistent with the data): the old `--recover` kept event bytes
queued after the unbind, which a real reset would drop. The old ab2d recover result (3/6, power-on failing)
is now 3/3 with the reset-keyed model (measured: `ab2d-a-recover-1..3`). I did not prove the stale bytes
were the cause of the old failures; only that they are gone with this change.

## 2. B2 against base (A is not involved in these behaviours; ab2d = A + B2 + D as posted before)

Command: `harness/gen-spec.sh harness/spec-t2-a.txt base,b2,ab2d 1 3 a` then
`harness/run-batch.sh harness/spec-t2-a.txt logs/summary-t2-a.txt` (54 runs). Pass = the scenario's own
success condition (see emulator docstrings).

| scenario | base | b2 (B2 only) | ab2d (A+B2+D wide) |
|---|---|---|---|
| dead device (hci0 removed by the core) | 3/3 | 3/3 | 3/3 |
| recovering device (back, powered, class write 0x00) | 3/3 | **0/3** | 3/3 |
| power-off-started resume (`close-recover`) | **0/3** (BT-18) | **0/3** (BT-18) | 3/3 |
| dropcmd (event dropped, device autosuspends first) | 3/3 (1 rerun, below) | 3/3 | 3/3 |
| dropcmd-wedge (needs a reset) | 3/3 | **3/3** | 3/3 |
| healthy cycles, 30 each | 3/3, 0 failures | 3/3 | 3/3 |

`base a-dropcmd-1` exit 3: I edited the emulator while the batch ran and the guest read a half-written
file (log shows IndentationError). Rerun as `base-a-dropcmd-1b`: PASS.

Workqueue block of BT-19 (`metrics.py`: seconds from the `tx timeout` line to btusb_reset() handing back):

| run | stall | tx timeouts | notes |
|---|---|---|---|
| `base-a-dead-1` | **5.380 s** | 1 | `Failed usb_autopm_get_interface: -16` |
| `b2-a-dead-1` | 0.002 s | 3 | each queued command times out on its own, 3 lines |
| `ab2d-a-dead-1` | 0.001 s | 3 | same |
| `base-a-recover-1` | 3.602 s | 1 | btusb_reset's own second reset |
| `ab2d-a-recover-1` | 0.009 s | 2 | |

Verdict (measured): **B2 removes the 5 s block and keeps the reset a wedged-but-awake controller needs**
(dropcmd-wedge 3/3 reset seen and usable; original B: 0/3). Two facts to carry with it:
- **B2 does not stand alone.** Without D a device that recovers after the reset-resume stays dead (0/3,
  and power-off-started resume 0/3, which base also fails). Base recovered the first only through the
  second reset of BT-19, which B2 removes. So B2 needs D (or a USB core fix for BT-18).
- The README's open item 2 stands: with B2 each queued command times out separately while the device resumes.

Focused reading (source, not run): `hci_unregister_dev()` disables `cmd_timer` synchronously
(`hci_core.c:2801`) before `hci_dev_do_close()`, so `hci_cmd_timeout()` cannot run during or after the
unregistration, and B2's early return cannot race it. B2's `reset_work` is cancelled after
`hci_unregister_dev()` in `btusb_disconnect()` (waits for a run blocked in `usb_autopm_get_interface()`,
which ends with the failing resume; no lockdep report in any of the 12 dead-device runs). The only other caller of
`hdev->reset` is sysfs `reset_store()`, drained by `device_del()` inside `hci_unregister_dev()`. After the
early return `hci_cmd_timeout()` sets `cmd_cnt = 1` and requeues `cmd_work`: the next command is deferred
again and times out about 2 s later (the three timeout lines). Earlier sysfs reset runs (old logs, not rerun here):
`b2-h2-sysfs-1`, `b2-h2-sysfs-def-1`.

## 3. D narrowed (`patches/0003-...Recover-after-a-runtime-reset-resume.patch`, kernel `ab2dn`)

Design: `btusb_suspend()` records `PMSG_IS_AUTO()` in `data->suspend_auto` (at the real suspend);
`btusb_reset_resume()` calls `btusb_resume()` and, if `suspend_auto` and `BTUSB_RESET` was not set, takes
`usb_autopm_get_interface_no_resume()` and calls `usb_queue_reset_device()`. `BTUSB_RESET` already means
"reference held for a queued reset"; `btusb_disconnect()` releases it. Callback order (source): the core
calls `suspend` for interface 1 then 0 (the first does the real suspend and records the flag) and
`reset_resume` for 0 then 1 (reset queued from 0's call, before 1's real resume; the reset work waits for the
resume to end, `usb_autoresume_device()` inside `usb_reset_device()`).

Runtime-path runs, `ab2dn` (`harness/spec-t3-matrix.txt`, `logs/summary-t3-matrix.txt`, 18 runs):

| scenario | ab2dn |
|---|---|
| dead device | 3/3 (stall 0.004 s, 3 timeouts) |
| recovering device | 3/3 |
| power-off-started resume | 3/3 |
| dropcmd | 3/3 |
| dropcmd-wedge | 3/3 |
| healthy cycles, 30 each | 3/3 |

Delayed-reset test (reviewer 7's "delay the reset work past the autosuspend"; kernels with a debug-only
usbcore parameter `bt17_reset_delay_ms` that sleeps 3 s in the reset work, autosuspend delay 500 ms,
`bt17 --fail-at 1 --recover --reset-delay-ms 3000 --expect-rebind`, `logs/summary-t3-delay.txt`):

| kernel | result | evidence |
|---|---|---|
| `ab2d-dbg` (D wide, no PM reference) | **FAIL 0/3** | device auto-suspends at 12.57 (`usb auto-suspend` line) before the queued reset runs; one USB reset only, no rebinding, `hci0_removed=False`. The core drops the request silently (`usb_lock_device_for_reset()` -> -EHOSTUNREACH, `usb.c:902`; inferred from the missing second reset, the core logs nothing) |
| `ab2dn-dbg` (narrowed, reference held) | **PASS 3/3** | two USB resets, hci0 removed and back, class write 0x00 |

Here Bluetooth still works after the dropped reset because the emulated controller does not lose state; the
test measures that the reset was lost, not a user-visible failure.

**System-suspend path: untested.** `vhci_hcd` refuses system suspend while a device is attached, and the Raw
Gadget emulator cannot take part in a system resume (README, open item 1). Static reading says the flag keeps
a system suspend of an awake device out of the new path. **It does not for a device that was already
runtime-suspended when the system went to sleep:** `usb_suspend_both()` returns early for a suspended device,
`btusb_suspend()` does not run again, `suspend_auto` stays true, and a reset-resume at the system resume would
queue the reset (stated in the commit message). The flag records the kind of suspend, not of resume; a
discriminator on the resume side (candidate: `udev->dev.power.runtime_status == RPM_RESUMING`, not tried)
would close it. Since the laptop's idle controller is usually runtime-suspended at sleep, this is the common
case, so "system path unchanged" is not established.

## Open

- System-suspend path of D (above); a USB core fix for BT-18 remains the reviewers' preferred route.
- No emulation of a reset that clears controller state (finding 16), so D's "traffic before rebinding"
  concern is untested.
- B2's message still says what the older B said about the rebinding; reword before any send (not done here).
- Patch 0001 (A) and 0002 (B2) in `patches/` are the earlier commits unchanged (B2 message as before).
- Debug-only commit (usbcore delay) is on branch `lane1-ab2dn-dbg` and `lane1-ab2d-dbg` in `lx`, not in `patches/`.
- checkpatch `--strict --no-tree` on 0003: only the missing Signed-off-by.
