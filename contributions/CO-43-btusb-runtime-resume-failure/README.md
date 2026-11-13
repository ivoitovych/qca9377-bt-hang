# CO-43 — btusb: a device that fails, or needs a reset, to resume (BT-18, BT-19, BT-20; BT-17)

**Where it comes from:** BT-17 (2026-11-12 18:03). The laptop's idle QCA9377 (`13d3:3503`)
was runtime-suspended, and the next command started a resume that the device never answered.
The outside reviews (`reviews/2026-11-13T02*`–`T04*-bt17-*`) agree on how the kernel then
behaved. An emulation reproduces it step by step and found three btusb defects on the way
(`results/bt17-emulation-2026-11-13/`):

- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-19:** `btusb_reset()`, called by the command timeout:
  - blocks the ordered HCI workqueue behind the failing resume (5.3 s on the laptop, 5.4 s in
    emulation);
  - when the reset-resume succeeds, resets the device a second time.
- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed: no
  `reset_resume` callback, and the USB core does not rebind after a runtime resume. Bluetooth
  stays dead with a healthy device.

None of the three made the controller stop answering. That cause (firmware, platform power,
or the AMD host) is not addressed by any patch here and needs a recurrence on the laptop with
USB core debug.

**State (2026-11-13): five patches written on bluetooth-next `da3cc0258` and tested in
emulation; nothing sent.** Patches in `patch/`, in this order, without Signed-off-by (the
operator adds his own). checkpatch `--strict --no-tree` reports only the missing Signed-off-by,
plus on patch 5 an unknown commit id (no tree) and two CamelCase notes for the USB core's own
`idVendor`/`idProduct`.

| # | subject | fixes | for upstream? |
|---|---|---|---|
| 1 (A) | Bluetooth: btusb: Report a failed resume for deferred data | BT-20 | yes, small |
| 2 (B) | Bluetooth: btusb: Don't reset a device that has not resumed | BT-19 | yes |
| 3 (D) | Bluetooth: btusb: Recover after a reset-resume | BT-18 | yes, after a system-suspend test |
| 4 (E) | Bluetooth: btusb: Anchor a deferred URB under txlock | BT-23 | yes, small |
| 5 (C) | Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen | BT-17 H3 | **RFC only**: one occurrence |

**Measured** (QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume;
`results/bt17-emulation-2026-11-13/README.md`, "Results"): see that table. In short:
- **unpatched:**
  - dead device: the laptop's sequence;
  - recovering device: back only through `btusb_reset()`'s second reset (BT-19);
  - power-off-started resume: Bluetooth dead, 5 of 5;
- **A+B+D:**
  - dead device: no stall, no reset, the failed resume logged;
  - recovering device: back, 5 of 5;
  - power-off-started resume: back, 5 of 5;
  - healthy cycles unchanged;
- **C** on a guest that sees the laptop's Ryzen CPU: the device no longer suspends while
  hci0 is up, so the fault does not occur; on a non-Ryzen guest C changes nothing.
- **E**, with a debug-only delay that widens BT-23's window and a resume forced inside it:
  - unpatched: parked and timed out, 3 of 3;
  - with E: answered, 2 of 2.

**Ubuntu:** all five apply, in order, to Ubuntu `7.0.0-42`'s single `drivers/bluetooth/btusb.c`
with line offsets only (`tmp/bt17-review/ubuntu-port-check.sh`, a dry run on a copy). A test
module for the laptop's `-43` would need `-43`'s btusb source and the operator's word to install.

**The list's CI bot, run locally** (`scripts/bot-ci-local.sh`, patches 1–4, the RFC left out;
`tmp/bot-ci-local/co43-20261113/`):
- every build and static check passes: BuildKernel, BuildKernel32, CheckAllWarning,
  CheckSparse, CheckKernelLLVM, IncrementalBuild, SubjectPrefix, VerifyFixes, TestRunnerSetup;
- CheckPatch, VerifySignedoff and GitLint fail only for the missing Signed-off-by;
- the base side (`da3cc0258`) passes its six tree checks too;
- the bot's file mapping selects no tester for a btusb-only change. The emulation above is
  what exercises the code.

**Open before any send:**
1. **D changes the system-resume path** of every btusb device that is reset-resumed at a
   system resume. That is one USB reset more, before a rebinding they already got.
   - **Affected:** the devices of `btusb_needs_reset_resume_table`, and **all Realtek
     devices** with wakeup disabled (`btusb_suspend()` sets `reset_resume` for them,
     `BTUSB_WAKEUP_AUTOSUSPEND`). The second group is the wider one.
   - **Narrower variant to weigh:** queue the reset only for a runtime resume. This harness cannot test it: `vhci_hcd`
   refuses system suspend while a device is attached (`platform_pm_suspend returns -16`,
   `results/bt17-emulation-2026-11-13/logs/runs/*-pm-sysfreeze-*`). A second emulator on
   Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`) brings btusb up and works before the
   sleep, but it cannot take part in a system resume: the freezer stops the user-space
   gadget until the devices have resumed. raw-gadget then leaves its running state
   ("device is not running"), and the re-enumeration fails (`logs/runs/base-pm-rg-plain-2.log`).
   Next: an in-kernel gadget function for this device, or a real QCA ROME on a spare machine
   with a DMI-table quirk set through `usbcore.quirks=13d3:3503:b`.
2. B makes each queued command time out on its own while the device resumes (three `tx
   timeout` lines in emulation instead of one blocked one). Acceptable, but the maintainers may
   prefer the core not to restore credit then.
3. The bot's CI on base and base + series (`scripts/bot-ci-local.sh`); an outside review.
4. C waits for evidence (a recurrence with USB core debug, an A/B with `power/control=on`).
5. **Four outside reviews of the intermediate document**
   (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`, each finding checked).
   They supersede the plan in item 6.
   - **B:** a blocker. It can skip the reset of an awake controller that swallowed a command:
     the autosuspend and the command timeout are both 2 s (not yet tested). Its exception
     never fires, as our own `ab-recover-1.log` shows. And its message is wrong about where the
     rebinding comes from: from btusb's reset, not from the core.
   - **D:** not as a fix.
     - It opens `autosuspend_check()`'s gate for reset-resume-quirk devices.
     - It replays traffic before the rebinding.
     - It still costs two resets, as unpatched.
     - So BT-18 goes to linux-usb as a USB core question first, with D as the btusb fallback.
   - **CO-44:** add the missing `-EACCES → MGMT_STATUS_AUTH_FAILED` case, once its reach is
     traced.
   - **E and A:** to send alone.
   - **C:** stays local.
   - **A fifth review (reviewer 7, `reviews/2026-11-13T1700Z-…-reviewer-7-verbatim.md`;
     checks 12–21 in the same file).** It reaches the same verdicts, and every source claim
     in it holds. New:
     - **B:** the exact counterexample. `tx_in_flight` drops at USB completion, so a command
       sent but never answered lets the device autosuspend before the timeout. Our
       `--hold-hci` cannot show it; the test needs a dropped HCI event and an autosuspend
       delay under 2 s.
     - **D:** its queued reset can be lost. `usb_lock_device_for_reset()` refuses a suspended
       device and gives up after 1 s, the work drops the request silently, and D holds no PM
       reference. And with `reset_resume` present, the core no longer sets `needs_binding`.
     - **D:** returning on a failed `btusb_resume()` would not help: `usb_resume_both()`
       ignores the result.
     - **BT-24:** `btusb_resume()`'s failure path scuttles `deferred` outside `txlock`, which
       E does not cover. Registered.
     - **The harness:**
       - `--recover` recovers on unlink, not on reset;
       - `recover` judges only that hci0 reappears;
       - failures do not fail the run.

       To be fixed before any further acceptance run.
     - **C's message:** the GET_STATUS failure is inferred, not logged on the laptop; narrow the
       subject.
6. **The second outside review of the patches (earlier, on the dossiers)**
   (`reviews/2026-11-13T1530Z-bt17-patches-reviewer-2-verbatim.md`, checked there):
   - **Don't send 1–4 as one series.** A and E go separately; B after another review; D only
     after a narrower design.
   - **D:**
     - queue the reset only after a runtime suspend, recording `PMSG_IS_AUTO()` in
       `btusb_suspend()`, so the system-resume path stays as it is;
     - say why the reset is queued even when `btusb_resume()` fails;
     - check the order of the two interfaces' callbacks against `suspend_count`.
     - Prototype and test that variant in the emulator. The runtime path is testable here; the
       system path still is not.
   - **B:** a focused reading of `hci_cmd_timeout()` and `hci_cmd_work()` when B returns early,
     above all when the device is about to be unregistered. Also correct the message's last
     line.
   - **E:** a final review of the lock order and the teardown cases.
   - **Order of sending, by the review's priority:** CO-44, then E, then A, then B, then D;
     C as an RFC only.
   - **`scripts/bt17-arm-usb-debug.sh`:** make the usbmon capture rotate instead of stopping
     at 500 MB, and have `--off` restore the saved state.

**Decides:** the operator, for any send.
