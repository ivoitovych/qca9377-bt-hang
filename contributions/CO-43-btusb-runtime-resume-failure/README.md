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

**Open before any send:**
1. D changes the system-resume path for the devices of `btusb_needs_reset_resume_table` (one
   USB reset more before the same rebinding). This harness cannot test it: `vhci_hcd`
   refuses system suspend while a device is attached (`platform_pm_suspend returns -16`,
   `results/bt17-emulation-2026-11-13/logs/runs/*-pm-sysfreeze-*`). Next: the same device on `dummy_hcd` with a raw-gadget emulator
   (both already in the guest config), or a real QCA ROME on a spare machine.
2. B makes each queued command time out on its own while the device resumes (three `tx
   timeout` lines in emulation instead of one blocked one). Acceptable, but the maintainers may
   prefer the core not to restore credit then.
3. The bot's CI on base and base + series (`scripts/bot-ci-local.sh`); an outside review.
4. C waits for evidence (a recurrence with USB core debug, an A/B with `power/control=on`).

**Decides:** the operator, for any send.
