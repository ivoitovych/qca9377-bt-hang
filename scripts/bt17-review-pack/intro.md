# Intermediate review: btusb resume-failure patches (CO-43) and the MGMT timeout status (CO-44)

**Date:** 2026-11-13. **State:** patch candidates, tested in emulation, **not sent anywhere**.
**Base:** bluetooth-next `da3cc0258` ("Bluetooth: hci_vhci: Report write readiness with queued
input", 2026-11-12) for the kernel; BlueZ master `20ffd285b` for the test.

This document is meant to be complete on its own. Everything a reviewer needs is in it: the
incident, the defects, every patch in full, the unpatched code they change, the emulator that
tested them, the results and the logs. Nothing has to be fetched. The project's repository is
<https://github.com/ivoitovych/qca9377-bt-hang>; paths below are relative to it.

## 1. What we ask of you

Please review the seven patches in section 5 for **correctness first**: locking, runtime PM and
USB core semantics, races, and paths we did not test. Then judge whether each one is ready for
the linux-bluetooth list, and whether the series order and split are right. Specific questions:

1. **Patch 2 (B), `btusb_reset()`:** the skip condition is `test_bit(BTUSB_SUSPENDING) &&
   !pm_runtime_active(&intf->dev)`.
   - Is reading the runtime PM status without the PM lock sound here (the HCI workqueue,
     racing with the USB core's resume)?
   - Which states can pass the check and still block in `usb_autopm_get_interface()`?
   - Is "a reset-resumed device whose interface is active although `btusb_resume()` never ran"
     the only case where the old reset is still wanted?
   - Known wording issue: the message's last line says "while BTUSB_SUSPENDING is set". The
     code also requires the interface not to be runtime-active. The line will be corrected
     before any send.
2. **Patch 3 (D), `btusb_reset_resume()`:** it calls `btusb_resume()` and then
   `usb_queue_reset_device()` on the primary interface, so the core unbinds and rebinds btusb.
   - Is queueing a reset from inside a reset-resume callback safe, for runtime and system
     resume? Think of the core's `usb_lock_device_for_reset()`, the interface's `needs_binding`
     state, and a disconnect racing the queued work.
   - **Its known cost:** at a **system** resume, the devices that were already reset-resumed and
     rebound get one more USB reset. That covers `btusb_needs_reset_resume_table` and every
     Realtek device with wakeup disabled (`btusb_suspend()` sets `reset_resume` for them). We
     could not test system suspend in emulation (section 7).
   - Would you rather queue the reset only for a runtime resume? Or is the right fix in the USB
     core instead (rebinding marked interfaces after a runtime resume too)?
3. **Patch 1 (A), `btusb_waker()`:** it logs a failed resume except `-EACCES` (runtime PM
   disabled during a system sleep transition). Is that the right exception, and is the log
   level right?
4. **Patch 4 (E), `submit_or_queue_tx_urb()`:** it anchors the deferred URB inside the `txlock`
   section instead of after it.
   - Is calling `usb_anchor_urb()` under `spin_lock_irqsave(&data->txlock)` acceptable?
   - Does `btusb_resume()`'s `play_deferred()` path still see every URB exactly once?
5. **Patch 5 (C), RFC:** it disables runtime suspend of `13d3:3503` on Ryzen when it hangs
   directly off a root hub, with the condition of `dcaf83ead130` (MT7922/MT7925).
   - It rests on one occurrence. Is it justified to post as an RFC, or only after a
     recurrence with USB core debug?
6. **CO-44, the MGMT patch:** `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`.
   - Do you know of any user-space code, BlueZ or other, that relies on 0x05 for a timed-out
     command?
   - Is `Fixes: 161510ccf91c` the right tag, and should it go to stable?
7. **The tests:** which failure path did we miss?
   - Where does the emulator (section 8) differ from a real QCA ROME on an AMD xHCI in ways that
     matter for these patches?

Please mark each finding with its patch number and a severity: blocker, should-fix or nit.
Where you can, also say whether you checked it against the source or are reasoning from the
text.

## 2. The incident in brief (BT-17)

- **The machine:** a laptop with a Qualcomm QCA9377 Bluetooth controller, USB ID `13d3:3503`
  (IMC Networks), on the AMD xHCI of a Ryzen 7 5825U.
- **The kernels:** Ubuntu `7.0.0-42`, with btusb built with `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y`.
  The device's entry gives it `BTUSB_QCA_ROME`, so `hdev->reset` is `btusb_qca_reset()`.
- **The sequence, 2026-11-12:**
  1. 18:00:28: the idle controller was runtime-suspended.
  2. 18:03, at the user's desktop login: the kernel's Write Class of Device (`0x0c24`) got no
     answer, and `command 0x0c24 tx timeout` followed.
  3. Five seconds later: USB resets of the port. They failed with `-71`, and the device left
     the bus.
  4. It stayed off through a reboot and came back only after a power-off.
  5. bluetoothd logged "Authentication Failed (0x05)" for MGMT commands that had simply timed
     out.
- **Outside reviews of the source** (five, recorded in the repository) agreed:
  - the first USB reset came from the USB core's reset-resume, after a 5 s GET_STATUS timeout
    in `finish_port_resume()`;
  - btusb's own reset (`btusb_reset()` from `hci_cmd_timeout()`) blocked behind that resume
    and never ran.
- **An emulation reproduced this kernel sequence step by step** (section 7). Real btusb in a
  QEMU guest drove an emulated `13d3:3503` that stops answering at a resume.
- **Not addressed here:** why the chip stopped answering (firmware, platform power or the AMD
  host). No patch here claims to fix that.

The incident's own evidence (excerpts of the laptop's kernel log, with every command used) is
in section 3.

## 3.–10. Contents

3. The incident's evidence (laptop)
4. The defects (the issue register's entries BT-17 to BT-23)
5. The patches, in full
6. The unpatched code they change (bluetooth-next `da3cc0258`)
7. The emulation: method, results and the matrix summaries
8. The emulator and harness source, in full
9. Representative test logs (kernel lines)
10. The dossiers (CO-43, CO-44): state, CI results and open items
