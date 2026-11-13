# BT-17 patches — outside reviewer 6's review of the intermediate document

*Received 2026-11-13 in answer to `2026-11-13T1100Z-bt17-patches-intermediate-review.md`. The text
is kept as received, except for the reviewer's tooling marks, which `scripts/review-text-clean.py`
removes. What we checked, finding by finding, and the plan that follows are in
`2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`.*

---

Pulling the review document and the context on the BT-17 patch work.
Verdict: CO-44 and patch 4 (E) are ready to send. Patch 1 (A) needs a wording fix. Patch 2 (B) has a blocker, patch 3 (D) should go out as an RFC to linux-usb rather than as a fix, and patch 5 (C) should stay home.
Basis: I read the patches against mainline master fetched today, not `da3cc0258`; your §6 excerpts match it. Nothing was run. "Source" below means checked there; "text" means reasoned from your document.
Patch 2 (B)
Blocker (source plus your timings, not run): B suppresses the reset for a controller that is awake and swallows a command.

* The autosuspend delay and `HCI_CMD_TIMEOUT` are both 2 s. With no connections, `tx_in_flight` is 0 once the command URB completes, so `btusb_suspend()` sets `BTUSB_SUSPENDING` about 2.01 s after the send (your traces).
* `hci_cmd_timeout()` fires at 2.03–2.05 s in your traces. The interface is `RPM_SUSPENDED`, so B skips, although the command did reach the controller.
* It repeats on every later command. It hits Intel, Realtek and QCA without a reset GPIO, since all three fall through to `btusb_reset()`.
* Fix: test what the commit message argues, that the command never left, with `BTUSB_SUSPENDING && !usb_anchor_empty(&data->deferred)`.
* Missing test: an emulator mode that drops an HCI command while awake, base against B.

Should-fix (source): `pm_runtime_active(&intf->dev)` does not mean "the device resumed".

* USB interfaces have no runtime callbacks, so `usb_autopm_put_interface()` suspends the interface immediately. It is active only while someone holds a usage count.
* In the BT-18 state nobody does, so the exception in your comment never fires. Unpatched code recovered only because `btusb_reset()` was already parked inside `usb_autopm_get_interface()`.
* So at commit 2/5 the `recover` scenario should go from "recovers" to dead. There is no A+B-only kernel in the matrix to show otherwise.
* Put the BT-18 fix before B and drop the clause.

Should-fix (text against log): the commit message contradicts 3/5.

* It says the core rebinds and btusb then resets a second time. In `base-m-recover-1.log` the order is marking (11.781533), `Resetting usb device.` (11.781578), forced unbind (11.781998). The rebind is btusb's reset.
* With D the recovering device still gets two resets (`final-m-recover-1`: 11.64 and 11.93). "Avoids a second reset" is not a benefit; the benefit is no 5 s stall.

Your sub-questions:

* The lock-free read is fine as a hint; both wrong answers are benign.
* What passes the check and still blocks: an autosuspend that has started but not yet reached `btusb_suspend()`.

Patch 3 (D)
Should-fix, and a blocker for a non-RFC send (source): adding `.reset_resume` opens a gate in `autosuspend_check()`.

* Devices with `USB_QUIRK_RESET_RESUME` are refused autosuspend when the driver has no `reset_resume`. That covers your three Dell DMI entries.
* With D they autosuspend whenever hci is closed (rfkill, powered off). Every power-on then becomes reset-resume, a second reset and a rebind in the middle of `btusb_open()`.
* This is not in the commit message or the dossier. `usbcore.quirks=…:b` on your test device trips the same gate.

Should-fix (source): the defect is in the USB core.

* Any autosuspend-capable driver without `reset_resume` is stranded after a runtime reset-resume.
* D buys the rebind with an extra USB reset, which is the operation that knocks your controller off the bus. The core's system-resume path rebinds without one.
* "Runtime only" is not cleanly available: the callback gets no `pm_message`, and `power.is_prepared` is not a driver's to read.
* Post D as an RFC with linux-usb and Alan Stern in Cc, asking whether `usb_runtime_resume()` should schedule the unbind and rebind. That also removes the system-resume cost and the gate problem.

Is queueing from the callback safe? Yes (source).

* `usb_lock_device_for_reset()` bails on NOTATTACHED, UNBINDING and UNBOUND, so a racing disconnect is covered.
* `usb_reset_device()` waits out the resume in flight.
* `usb_rebind_intf()` refuses to attach while `is_prepared`, so at system resume the rebind still lands in the complete phase.

Nits:

* The lock poll gives up silently after 1 s.
* Nothing pins the device until the work runs.
* D's path logs `urb … failed to resubmit (2)` at error level in both `final` logs. Explain it or expect the question.

Patches 1, 4, 5

* Patch 1 (A), nit (text): `-EACCES` is the right exception and the level is fine. "Nothing that said the resume had failed" overstates it: the unpatched log has `Failed usb_autopm_get_interface: -16`. A matters because B removes that line. It also prints twice and arrives at the disconnect, not at the timeout.
* Patch 4 (E), correct (source): the lock order already exists in `btusb_resume()`, exactly-once holds, and the refcount survives a resume completing before the sender's `usb_free_urb()`. Nits: add `Fixes: 7bee549e197c`; the debug patch shown is only the on-top-of-E variant.
* Patch 5 (C): don't post it. It is one occurrence against eight clean cycles, and `dcaf83ead130` is about remote wakeup while yours was host-initiated. Run it locally as the A/B.

CO-44

* Send it. Pairing completions take `u8` HCI statuses through the table (spot-checked).
* I know of no consumer keyed on 0x05 for a timeout, but I did not check non-BlueZ MGMT users.
* The `Fixes:` tag is right. Skip `Cc: stable`, say below the `---` that a user-visible status value changes, and ask Luiz whether the mapping was deliberate.
* Send the BlueZ test only after the kernel patch lands, or CI goes red.

Tests you missed

1. An awake controller that drops a command.
2. A+B without D.
3. A resume started by remote wakeup. vhci cannot signal one, and it is both the normal Bluetooth wake path and the one `dcaf83ead130` describes.
4. A reset-resume-quirk device with hci down.
5. Firmware reload after the rebind. The emulator always reports patch and NVM present.

Doc nit: the §7 README title says "four btusb candidates"; there are five.
Order: CO-44 and E now. Then the BT-18 fix via linux-usb, then B reworked on top with A.
