# BT-17 in emulation: the kernel's side of the incident, reproduced, and five btusb candidates (2026-11-13)

Everything here ran in QEMU guests on the investigation machine. Nothing touched the laptop's
Bluetooth, and nothing was sent anywhere.

## What it is

- **The kernel:** bluetooth-next `da3cc0258` (2026-11-12), with:
  - BlueZ's tester config plus SMP 4, KASAN, lockdep and dynamic debug;
  - usbip's virtual host controller;
  - `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y` (as on the laptop).
- **The device: real btusb against an emulated controller,** `harness/bt17-emu.py`, run
  inside the guest. It speaks usbip to `vhci_hcd`, so the kernel sees a USB device:
  - **Identity:** `13d3:3503`, bcdUSB 1.10, full speed, remote wakeup in bmAttributes, class
    e0/01/01, the laptop's endpoint layout. So btusb takes the `BTUSB_QCA_ROME` path:
    `btusb_setup_qca()`, `hdev->reset = btusb_qca_reset`.
  - **QCA vendor requests:** version ROM `0x302` / patch `0x3e8`; status `0xc0` (patch and NVM
    loaded), so no download.
  - **HCI:** answers the init sequence and every later command.
  - **Accounting:** counts device suspends (SET_FEATURE remote wakeup) and resumes (the next
    GET_STATUS).
- **The fault, `--fail-at N`:** at the N-th resume the device does not answer its GET_STATUS
  and holds every later request (a device that NAKs). When the host gives up (unlink), the
  device is "dead": every control transfer fails `-71`. With `--recover` it is healthy again
  instead. Strictly, it recovers when the host unlinks the held request, not at a USB reset
  (`Emu.unlink()`). So it models a device that answers again after the host's reset-resume, but
  cannot show that a reset is what brought it back.
- **The triggers:**
  - MGMT Set Device Class after the runtime autosuspend (`bt17`, the laptop's Write Class of
    Device at login);
  - MGMT Set Powered off (`close-recover`, btusb's close takes a PM reference);
  - a healthy loop (`cycles`).
- **Debug on:** USB core `hub.c` and `driver.c`, plus btusb's suspend, resume and disconnect,
  and the HCI command worker.

**What it can and cannot show:**
- **Can:** what the kernel does when a device stops answering after a runtime resume, on the
  same code path as the laptop's: the ROME reset hook, autosuspend, persist.
- **Cannot:**
  - why the QCA chip stopped answering;
  - what the AMD xHCI did. vhci handles port reset and SET_ADDRESS itself, so the xHCI
    errors of the laptop's tail (BT-22) do not appear here.

## The reproduction (unpatched kernel)

`logs/runs/base-bt17-2.log`. Times are from the moment the command reached btusb (the
`cmd_cnt` line). The laptop's are from `results/incident-2026-11-12-1803/`.

| | laptop (18:03, monotonic) | emulation |
|---|---|---|
| command handed to btusb | 178.731 | 16.229 |
| `usb auto-resume` (who started it) | not logged | +0.001 |
| `finish resume` (GET_STATUS sent) | not logged | +0.061 |
| `command 0x0c24 tx timeout` | +2.041 | +2.051 |
| MGMT Set Device Class / Remove UUID status | 0x05 | 0x05 |
| `retry with reset-resume` | not logged | +5.260 |
| first `reset full-speed` | +5.291 | +5.384 |
| four resets, then `gone after usb resume?` | resets only | yes |
| `USB disconnect` | +7.352 | +7.434 |
| `Failed usb_autopm_get_interface: -16` | +7.352 | +7.437 |
| `Resetting usb device.` | never | never |
| btusb `intf` prints | 2 at suspend, none at resume, 2 at disconnect | the same |

So H1 and H2 (the outside reviews) hold on this code, for a host-initiated resume of a device
that stops answering:
- the first reset is the USB core's reset-resume after a 5 s GET_STATUS;
- btusb's reset waits behind it and never runs.

## Defects found with it (registered in `docs/issues.md`)

- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed (no
  `reset_resume` callback; the core rebinds marked interfaces only after a system resume or a
  `usb_reset_device()`). Bluetooth stays dead with a healthy device. Reproduced by
  `close-recover` (unpatched: power-on fails, HCI Reset `-110` twice, MGMT 0x05).
- **BT-19:** `btusb_reset()` blocks the ordered HCI workqueue 5.4 s behind the failing resume.
  When the reset-resume succeeds, it then resets the device a second time
  (`Resetting usb device.` after the rebinding, `recover` scenario).
- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-21:** the MGMT 0x05 for a timeout (CO-44, tested separately with mgmt-tester).

## The candidates (`patches/`, CO-43), in series order

1. **A**, "Bluetooth: btusb: Report a failed resume for deferred data" (BT-20).
2. **B**, "Bluetooth: btusb: Don't reset a device that has not resumed" (BT-19): no wait and
   no reset while `BTUSB_SUSPENDING` is set and the interface is not runtime-active.
3. **D**, "Bluetooth: btusb: Recover after a reset-resume" (BT-18): a `reset_resume`
   callback that resumes and queues a reset, so the core rebinds btusb.
4. **E**, "Bluetooth: btusb: Anchor a deferred URB under txlock" (BT-23).
5. **C**, RFC, "Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen"
   (H3): the `BTUSB_WAKEUP_BROKEN` condition of `dcaf83ead130` for this one device.

`patches/debug-only/` holds the delay used to widen BT-23's window; it is a test tool, not a
candidate.

checkpatch `--strict --no-tree`: each reports only the missing Signed-off-by (the operator
adds his own), plus for patch 5 the no-tree commit-id warning and two CamelCase notes on the
USB core's own field names.

## Results

QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume. One guest per
run. Every log is in `logs/runs/` (named `<kernel>-<label>.log`, with `SHA256SUMS`); matrix
summaries are `logs/runs/matrix-*.txt`; each kernel's build record (commit, modified files,
key config) is `logs/bzImage-<kernel>.commit`.

| scenario | unpatched (`base`) | A+B+D (`abd`) | final series A,B,D,E,C (`final`) |
|---|---|---|---|
| dead device, resume started by a class write (`bt17`) | 5/5: the laptop's sequence; `hci_cmd_timeout()` blocked 5.4 s; `Failed usb_autopm_get_interface: -16` at the disconnect | 5/5: `Device not resumed; not resetting`, credit back at once; `Failed to resume device for deferred data: -16`; the core disconnects | 3/3 as A+B+D |
| device that answers again after the reset-resume, started by a class write (`recover`) | 5/5 hci0 back, through `btusb_reset()`'s second reset (`Resetting usb device.` in every run, BT-19) | 5/5 back through D's rebinding; no reset from btusb's timeout path, but still two USB resets, as unpatched: the reset-resume's and D's queued one (`final-m-recover-1`: 11.64 and 11.93; unpatched `base-m-recover-1`: 11.65 and 11.93, where btusb's reset causes the rebinding). The gain is no 5 s stall, not one reset fewer | 3/3 back |
| the same, started by powering hci0 off (`close-recover`) | **0/5**: Bluetooth dead afterwards (BT-18) | 5/5 works | 3/3 works |
| healthy suspend/resume cycles with a class write each | 50/50, median 0.062 s | 50/50, median 0.064 s | 50/50, median 0.063 s |
| dead device, guest with the host's CPU (Ryzen 7 5825U) | fails as above | — | the device no longer autosuspends with hci0 up (C); the fault never arises |
| the same with C, guest CPU not Zen (`abdc`) | — | — | as A+B+D (C does not apply) |
| BT-23, window widened to 400 ms by a debug-only delay, resume forced inside it (`bt23`) | 3/3: parked on an active device, timed out after 2.02 s, MGMT 0x05 | — | E: 2/2 answered after 0.40 s; 20/20 healthy cycles |
| system suspend (`pm_test=devices`, freeze) | not testable here. `vhci_hcd` refuses system suspend with a device attached (`platform_pm_suspend returns -16`), both kernels. A second emulator on Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`, `*-rg-*` logs, `SHA256SUMS-raw-gadget`) works before the sleep, but the freezer stops the user-space gadget during the resume ("device is not running") | | |

Kernel reports (`BUG:`, `WARNING:`, KASAN, lockdep, hung task) in any run: none.

**How the results were judged** (outside review, reviewer 7):
- **`recover`:** "hci0 back" means that hci0 reappeared. That scenario does not power it on or
  send a command afterwards, and its `RESULT` line leaves the value out; it was read from the
  `hci0 back after recovery` line.
- **Functional checks:** only `close-recover` and `sysfreeze` write the class after the recovery.
- **Exit status:** the harness does not fail by itself. A scenario's exception is logged and
  swallowed, `run-guest.sh` ends with a `grep`, and `run-matrix.sh` checks nothing.
- **Every count above** was read from the logs by hand.
- **Before any further acceptance run**, the harness gets functional `RESULT`s and non-zero exits
  (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`, finding 18).

**The laptop tool `scripts/bt17-provoke.py`, run unchanged in a guest:**
- healthy device: 18 cycles, 18 answered;
- device failing at resume 4: "FAILURE at cycle 4", with the device's runtime status
  `resuming` in its record.

Its first version had a 14-byte HCI filter, which the kernel refuses (EINVAL; `struct
hci_ufilter` is 16 bytes with padding). The emulator caught it; fixed before any laptop use.

## Rerunning

- `harness/build-guest-kernel.sh <tag>` builds from a bluetooth-next worktree.
- `harness/run-guest.sh <tag> <label> <scenario> [--fail-at N] [--recover]` runs one guest;
  `harness/run-guest-hostcpu.sh` passes `-cpu host`, so the guest sees the Ryzen.
- `harness/run-matrix.sh <tag> <first> <last>` runs the repeat matrix.

Paths in the scripts are those of the work directory `/root/exp/agent-work/bt17-emu-20261113/`.
