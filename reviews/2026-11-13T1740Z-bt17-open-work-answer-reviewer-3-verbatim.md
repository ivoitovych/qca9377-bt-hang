# BT-17 open work — outside reviewer 3's answer to the task document

*Received 2026-11-13 in answer to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`, stored
2026-11-14: it had been left out when the other answers were stored on 11-13. The text is kept
as received, except for the reviewer's tooling marks, which `scripts/review-text-clean.py`
removes. What we checked, point by point, is in
`2026-11-14T1300Z-bt17-open-work-reviewer-3-checks.md`.*

---

I reviewed the new document end-to-end and then independently checked the relevant Linux USB/Bluetooth source, the old btusb reset-resume history, recent 2026 btusb work, HCI timeout handling, URB ownership, and MGMT precedent.

The document is now substantially stronger than the 11:00 version. In particular, its conclusions that **B is wrong**, **D is not an acceptable fix**, and **`-EACCES` should not simply be added to CO-44** are correct. I found two additional results that I think materially change the next step: **T2 has unusually decisive historical prior art against generic `btusb_reset_resume()`**, and the **T3 “suspected” leak is source-confirmed, not merely suspected**.

## Findings

| Severity | Task / location on `da3cc0258` | Finding |
|---|---|---|
| **blocker** | T1, `btusb_reset()` ~1095 | There is no sound one-line replacement for B. `pm_runtime_get_if_active()` alone fails `dropcmd-wedge`; `usb_autopm_get_interface_async()` alone can lose the reset. A correct solution needs asynchronous recovery plus a “recovery in progress” send gate. |
| **blocker** | T1 + T2 | Meeting T1(a–d) cleanly **depends on resolving BT-18**. On today's USB core you must choose between a second reset or leaving the successful reset-resume in the broken `needs_binding` state. |
| **blocker** | T2, `usb_resume_interface()` ~1367 | Generic `.reset_resume = btusb_resume` was already tried upstream in 2013 and explicitly reverted because some devices return to HID mode after USB reset and require re-enumeration/udev setup. |
| **should-fix, confirmed** | T3, `btusb_resume()` ~5075, `btusb_close()`, `play_deferred()` ~4989 | The deferred-URB leak is real: scuttle releases URB references but does not free the skb or control setup packet. `play_deferred()`'s error cleanup also leaks the skb. |
| **should-fix, confirmed** | T3, `btusb_resume()` ~5075–5080 | BT-24 is real. Drain + clear must be serialized with the sender's defer decision/insertion. With E applied, doing both under `txlock` closes it. |
| **question, real gap** | T4, `hci_core.c` ~4351 | Suppressing `cmd_timer` during `HCI_RESET` appears deliberate because the synchronous reset has its own timeout, but it leaves the driver's recovery hook unreachable if the HCI Reset itself disappears. I found no historical discussion explicitly explaining that policy. |
| **ready** | CO-44 | Keep it **one line**. The `-EACCES` ambiguity analysis in the document is correct. There is very strong recent precedent for repairing `mgmt_errno_status()` after hci-sync conversions. |
| **ready after wording** | A | No technical blocker found. |
| **ready** | E | No new blocker. Keep it strictly scoped to the successful-resume race. |
| **RFC only** | C | Still not enough evidence for a permanent quirk. |

### T1 — I would not replace B with `pm_runtime_get_if_active()`

The document's new `dropcmd-wedge` run is decisive. Once the USB transfer has completed, `tx_in_flight` is zero; the controller can autosuspend while the HCI response is still outstanding. Thus an inactive/suspended PM state does **not** tell us whether the command reached the controller.

Conversely, during a successful *runtime* autosuspend, an actually in-flight TX URB cannot survive the suspend transition: `btusb_suspend()` rejects the autosuspend while `tx_in_flight` is nonzero. So for the particular runtime-PM scenario you care about, there is a useful distinction between a command still on `deferred` and one whose USB transaction completed.

I would nevertheless not use plain `!usb_anchor_empty(&data->deferred)` as the long-term semantic test. The anchor contains TX URBs, not specifically “the command whose HCI timer expired.” It is a good practical discriminator in the current serialized command path, but the invariant is indirect. I would either track deferred HCI commands explicitly under `txlock`, or at minimum document why a deferred HCI command at this point must be the outstanding one.

The mechanism I think has the right shape is:

```c
/*
 * Sketch only -- lifetime/teardown details still need proving.
 *
 * BTUSB_RECOVERY_PENDING:
 *   - set when timeout recovery has been handed away from hdev->workqueue
 *   - btusb_send_frame() rejects new TX while it is set
 *   - a successful resume/rebind or failed recovery clears/discards it
 */
static void btusb_reset(struct hci_dev *hdev)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	unsigned long flags;
	bool command_deferred;

	spin_lock_irqsave(&data->txlock, flags);
	command_deferred = btusb_timed_out_command_is_deferred(data, hdev);

	if (!command_deferred &&
	    !test_and_set_bit(BTUSB_RECOVERY_PENDING, &data->flags))
		schedule_work(&data->reset_work);

	spin_unlock_irqrestore(&data->txlock, flags);

	/*
	 * Never wait for runtime PM here.  hci_cmd_timeout() is running
	 * on the ordered HCI workqueue.
	 */
}
```

The worker may then synchronously acquire a PM reference and perform or queue the reset **outside the HCI ordered workqueue**. `pm_runtime_get_if_active()` is useful only as a fast-path optimization; it cannot be the decision because `dropcmd-wedge` correctly needs recovery while suspended. `usb_autopm_get_interface_async()` is likewise insufficient on its own: if reset work arrives before the async resume finishes, `usb_lock_device_for_reset()` can return `-EHOSTUNREACH` and silently lose the reset — exactly the failure already identified in D.

There is good current precedent for asynchronous driver recovery. Intel's PCIe Bluetooth driver schedules reset work instead of doing recovery inline, has a `RECOVERY_IN_PROGRESS` state, coalesces reset requests, and rejects TX while recovery is in progress. [GitHub](https://github.com/torvalds/linux/blob/master/drivers/bluetooth/btintel_pcie.c) That is much closer to the architecture I would copy than B's PM snapshot.

The **send gate is important**. Once `hdev->reset()` returns, `hci_cmd_timeout()` restores the HCI command credit. Without a gate, an asynchronous btusb reset would let the next queued command run during recovery. I would not deliberately accept three successive two-second timeouts. Have `btusb_send_frame()` fail fast while `BTUSB_RECOVERY_PENDING` is set instead.

There is, however, a fundamental dependency on T2. Suppose the recovery worker waits through a resume and usbcore successfully performs reset-resume. Because btusb lacks `reset_resume`, the interface acquires `needs_binding`. At that point:

- queueing another USB reset recovers it today, but violates T1(c);
- not resetting avoids the duplicate reset but leaves BT-18 dead;
- doing a private btusb rebind is duplicating USB-core policy and has multi-interface problems.

So **I don't think a complete B replacement should be written before the USB maintainers answer T2**. This is not merely convenient ordering; the two problems intersect at exactly the recovery decision.

One other consequence is worth recording. If the timed-out command is still deferred, after its HCI request has timed out it should ideally **not later be replayed as a stale command** if the resume eventually succeeds. Tracking the specific deferred command rather than merely testing whether the anchor is nonempty gives you a way to remove that command safely. I would investigate this before finalizing T1; it may be another small latent bug exposed by this work.

### T2 — history strongly says “ask USB core first”

This was the most useful historical result.

In 2013 commit `502f769662978a2fe99d0caed5e53e3006107381`, Linux added exactly the obvious solution:

```c
.reset_resume = btusb_resume,
```

because usbcore was printing “no reset_resume for driver btusb?”. [ZX2C4](https://git.zx2c4.com/linux-rng/commit/drivers/bluetooth?h=jd%2Fvdso-test-harness\&id=502f769662978a2fe99d0caed5e53e3006107381)

It was then reverted by `b1a8014471b01dd862de9f91bbbff1296afac42d`. The revert explains why very clearly: many Bluetooth USB devices return to a BIOS-oriented HID mode after USB reset; btusb itself cannot switch them back to HCI mode, because userspace/udev does that. Therefore the correct behavior for those devices is to **have no generic `reset_resume` and let USB re-enumerate/rebind them**. The revert fixed multiple suspend/hibernate reports. [Linux-Kernel Archive](https://lkml.iu.edu/1311.3/01913.html)

That is essentially a historical upstream NAK to D's fundamental approach.

There is even more relevant 2026 evidence. A recent Intel proposal adds a `reset_resume` callback only for a *very narrowly defined* closed Intel adapter on an ACPI-manageable port. For everything else — explicitly including HCI-running adapters — it sets `intf->needs_binding = 1` and preserves the rebind behavior. [Linux-Kernel Archive](https://lkml.iu.edu/2609.2/05874.html) Oliver Neukum immediately asked about behavior with another device/S4 and about lost connection data, which illustrates how cautiously this callback is treated. [lists.openwall.net](https://lists.openwall.net/linux-kernel/2026/09/22/1292)

So my answer to T2 is:

**BT-18 should go to linux-usb as a USB-core/runtime-PM question, with linux-bluetooth copied. Do not resurrect generic btusb `reset_resume`.**

I think your interpretation of how this hole arises is probably right. Normally usbcore's autosuspend checks prevent a known `USB_QUIRK_RESET_RESUME` device from runtime-suspending if its interface driver cannot handle reset-resume. But the BT-18 route is different: an ordinary runtime resume is attempted first, it fails, and `finish_port_resume()` dynamically falls back to reset-resume because persist is enabled. That fallback can therefore reach a state which the normal autosuspend gate was meant to avoid.

The natural core semantics would be “if reset-resume marked interfaces `needs_binding`, arrange the same eventual unbind/rebind that the system-resume path promises.” I would **not** do the rebind inline inside `usb_runtime_resume()`: USB's own helper says the device lock is required, and reprobe can involve multiple interfaces and PM operations. [GitHub](https://github.com/torvalds/linux/blob/master/drivers/usb/core/driver.c) A deferred USB-core work item after the runtime-PM callback has unwound looks much more plausible, but that is exactly the design decision USB maintainers should make.

Here is the mail I would send:

While investigating a btusb runtime-resume failure I found a reset-resume case where an interface is marked for rebinding but the runtime PM path never performs that rebind.

The sequence is:

1. A USB Bluetooth device is runtime-suspended with persist enabled.
2. A host-initiated runtime resume fails.
3. finish_port_resume() retries with reset-resume and the USB reset succeeds.
4. btusb has no reset_resume callback, so usb_resume_interface() sets intf->needs_binding.
5. usb_runtime_resume() returns after usb_resume_both(), with no equivalent of the system-resume unbind/rebind path.

The result is that btusb remains bound but was never resumed. Its suspend state remains in effect and later TX is deferred indefinitely. I can reproduce this with the real btusb driver against an emulated USB device which becomes responsive after reset.

I also found the historical reason btusb intentionally has no generic reset_resume callback. Commit b1a8014471b01 ("Bluetooth: revert: \"Bluetooth: Add missing reset_resume dev_pm_ops\"") reverted .reset_resume = btusb_resume because some devices return to HID mode after reset and require USB re-enumeration and userspace setup.

Is the runtime-PM asymmetry intentional?

If usb_resume_interface() sets needs_binding during a successful runtime reset-resume, should usbcore arrange a deferred unbind/rebind after the runtime resume has completed, fail the resume, or handle this in some other way?

There is also an autosuspend_check() guard for USB_QUIRK_RESET_RESUME devices whose interface driver lacks reset_resume. In this case reset_resume was not known at suspend time; it arose only as the persist fallback after an ordinary runtime resume failed.

I can provide the reproducer and full USB-core/btusb trace if useful.

I would send that to both subsystem lists, with the maintainers returned by `get_maintainer.pl` for `drivers/usb/core/driver.c`, `drivers/usb/core/hub.c`, and `drivers/bluetooth/btusb_main.c`. The recent Intel thread itself copied both linux-bluetooth and linux-usb, so that cross-subsystem audience has direct precedent. [lists.openwall.net](https://lists.openwall.net/linux-kernel/2026/09/17/3066)

## T3 — BT-24 and BT-25

I would promote the leak from **“suspected” to “confirmed from source.”**

`usb_scuttle_anchored_urbs()` only removes URBs from the anchor and drops the anchor-held URB reference. `usb_free_urb()` in turn frees the URB itself and only frees a transfer buffer when `URB_FREE_BUFFER` is set. Neither operation knows that btusb stored its skb in `urb->context`, and neither frees a control URB's separately allocated `setup_packet`. [GitHub](https://github.com/torvalds/linux/blob/master/drivers/usb/core/urb.c)

For deferred btusb TX:

- `urb->context` is the skb;
- command URBs additionally own `urb->setup_packet`;
- the normal `btusb_tx_complete()` frees both;
- a deferred, never-submitted URB never gets that completion.

Therefore both scuttle sites leak the skb, and command URBs also leak the setup packet. `play_deferred()` is slightly better — its error cleanup frees `setup_packet` — but still leaks the skb when submission fails or when it cleans the remaining deferred queue.

I would factor ownership cleanup into one helper and use it everywhere. Based on E:

```diff
+static void btusb_free_deferred(struct btusb_data *data)
+{
+	struct urb *urb;
+
+	while ((urb = usb_get_from_anchor(&data->deferred))) {
+		dev_kfree_skb_any(urb->context);
+		kfree(urb->setup_packet);
+		usb_free_urb(urb);
+	}
+}
+
 static void play_deferred(struct btusb_data *data)
 {
 	struct urb *urb;
 	int err;

 	while ((urb = usb_get_from_anchor(&data->deferred))) {
 		usb_anchor_urb(urb, &data->tx_anchor);

 		err = usb_submit_urb(urb, GFP_ATOMIC);
 		if (err < 0) {
 			...
+			dev_kfree_skb_any(urb->context);
 			kfree(urb->setup_packet);
 			usb_unanchor_urb(urb);
 			usb_free_urb(urb);
 			break;
 		}
 		...
 	}

-	while ((urb = usb_get_from_anchor(&data->deferred))) {
-		kfree(urb->setup_packet);
-		usb_free_urb(urb);
-	}
+	btusb_free_deferred(data);
 }

 ...
 failed:
-	usb_scuttle_anchored_urbs(&data->deferred);
-done:
 	spin_lock_irq(&data->txlock);
+	btusb_free_deferred(data);
 	clear_bit(BTUSB_SUSPENDING, &data->flags);
 	spin_unlock_irq(&data->txlock);
+	return err;
+
+done:
+	spin_lock_irq(&data->txlock);
+	clear_bit(BTUSB_SUSPENDING, &data->flags);
+	spin_unlock_irq(&data->txlock);
```

The exact factoring of `done:` versus `failed:` can be cleaner than that sketch, but the important invariant is:

**with E, the failed-resume drain and clearing of `BTUSB_SUSPENDING` must occur in the same `txlock` critical section.**

Then there are only two legal outcomes for a sender: it gets the lock before failure cleanup and its URB is included in the drain, or it gets it afterward, sees `BTUSB_SUSPENDING` clear, and submits normally. BT-24 disappears.

`dev_kfree_skb_any()` is the right primitive here because `play_deferred()` is called with interrupts disabled under `txlock`.

I would initially **not** add “complete every dropped command with an error” to this patch. That changes HCI behavior and makes an otherwise crisp ownership/race fix harder to review. First fix the memory ownership and stranded-URB race. A separate patch can decide whether a resume failure should call `hci_cmd_sync_cancel()` earlier instead of relying on the HCI timeout.

A `kmemleak` test is still useful, but now as **validation of a source-proven bug**, not as the gate deciding whether the bug exists.

## T4 — HCI Reset

The source makes the policy clear even though I did not find the original discussion explaining it. `hci_reset_sync()` is itself a synchronous command with `HCI_CMD_TIMEOUT`; meanwhile `hci_cmd_work()` explicitly does not arm the generic command timer while `HCI_RESET` is set. [Google Source](https://code.googlesource.com/linux/torvalds/linux/%2B/7bcf809b1e7889ab7e75fe1fcf8f1a98332f36d2/net/bluetooth/hci_core.c) There is a parallel design signal in the ncmd path: during `HCI_INIT`, the code explicitly says the initialization procedure has its own timeout handling. [Google Source](https://code.googlesource.com/linux/torvalds/linux/%2B/5d144c294ae21c1bfb275ba06ec73c2d1ab7cf92/net/bluetooth/hci_core.c)

So I would classify this as:

**question, not yet defect: the suppression is probably intentional, but the resulting recovery hole is real.**

I would not “fix” it by simply allowing `cmd_timer` for HCI Reset. That would cause the generic timeout path to invoke the driver's reset callback while a synchronous HCI Reset/init operation is already in its timeout/cleanup path, creating exactly the sort of overlapping recovery that the suppression likely avoids.

The better Bluetooth-core question is:

> When an HCI Reset used by `hci_dev_open_sync()` itself times out, should the failed synchronous initialization invoke the transport's `hdev->reset` recovery hook *after* that request has failed, rather than enabling the generic command timer during HCI_RESET?

I searched current source and public mailing-list material around `HCI_RESET`, `cmd_timer`, `hci_cmd_work`, and reset timeouts. I found the behavior consistently present, but no useful historical explanation of the HCI_RESET exclusion. So on the original intent I am **not sure** beyond the source-level inference above.

## T5 — useful prior art

For CO-44, I found a very close 2026 precedent. Commit `65683fbed5c831df01b2df530b836ac6ca9e3f58`, “Bluetooth: MGMT: Return RFKILLED for Set Powered on a blocked controller,” fixes precisely the same class of problem: conversion to hci-sync caused an errno to run through `mgmt_errno_status()`, which lacked/corrupted the intended MGMT result, so userspace saw the wrong status. The patch adds the missing errno mapping and explains the observable bluetoothd behavior. [Kernel Git Repositories](https://kernel.googlesource.com/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git/%2B/65683fbed5c831df01b2df530b836ac6ca9e3f58)

That strongly supports CO-44's form. Your current decision **not** to add `-EACCES` is also correct: the errno conversion has already discarded whether the original HCI status was 0x05 or 0x18, while the MGMT HCI-status table distinguishes them. By contrast every source that becomes `-ETIMEDOUT` in this path agrees semantically with `MGMT_STATUS_TIMEOUT`; current source still shows the erroneous `-ETIMEDOUT → MGMT_STATUS_AUTH_FAILED` mapping alongside the table's timeout mappings. [GitHub](https://github.com/torvalds/linux/blob/master/net/bluetooth/mgmt.c)

I found no reason in `161510ccf91c` for choosing AUTH_FAILED; the change appears to have been introduced mechanically with the hci-sync conversion rather than justified as API semantics.

I would add `Cc: stable@vger.kernel.org` to CO-44. It is a tested, tiny, user-visible correctness bug with a clear `Fixes:` origin. Those are precisely the properties the stable rules ask for; the documentation also says a `Fixes:` tag alone does not replace the stable Cc for a stable candidate. [docs.kernel.org](https://docs.kernel.org/next/process/stable-kernel-rules.html)

For btusb reset history, there are two more useful precedents. The 2018 QCA work deliberately moved reset-resume handling to USB core rather than inventing a btusb-specific reset-resume implementation, and later narrowed the quirk by DMI because applying it to all QCA devices unnecessarily disabled runtime suspend on healthy platforms. [Upd.dev](https://upd.dev/torvalds/linux/blame/commit/53492a668e3b9b823fc9a3ba563a5d10fef32c03/drivers/bluetooth/btusb.c) That history argues both **against D** and **for keeping C very conservative**.

Also relevant to T1: a recent btusb fix, `c93922dd316b7273a8667d29084632066fa8a2d3`, repaired an actual PM-reference leak in `btusb_reset()`. Its discussion explicitly notes that the interface object and PM usage count survive the USB reset's unbind/rebind. [Kernel Git Repositories](https://kernel.googlesource.com/pub/scm/linux/kernel/git/bluetooth/bluetooth/%2B/c93922dd316b7273a8667d29084632066fa8a2d3) Any T1 rewrite that changes how long the PM reference is held needs to preserve that lesson.

I did not find a current competing patch for `btusb_waker()`, `play_deferred()`, `submit_or_queue_tx_urb()`, or the specific `BTUSB_SUSPENDING` races in public current material.

## T6 — wording I would use

These are the versions I would be comfortable putting through the final local checks.

### A

Bluetooth: btusb: Report a failed resume for deferred data

When data is sent while btusb is suspended, submit_or_queue_tx_urb()
places the URB on the deferred anchor and schedules btusb_waker() to
resume the interface.

If usb_autopm_get_interface() fails, btusb_waker() currently returns
silently and the deferred traffic remains queued. The immediate
Bluetooth-side symptom may therefore be an HCI command timeout, while
a later PM or reset path may report a different error.

Report the failure from btusb_waker(), except for -EACCES. Runtime PM
may be disabled for reasons including a system-sleep transition, so
-EACCES does not by itself identify a failed device resume.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")

### E

Bluetooth: btusb: Anchor a deferred URB under txlock

submit_or_queue_tx_urb() tests BTUSB_SUSPENDING under txlock, but
currently drops the lock before placing the URB on the deferred
anchor.

btusb_resume() drains the deferred anchor and clears
BTUSB_SUSPENDING while holding the same lock. If resume acquires
txlock after the sender has decided to defer but before the URB is
anchored, it drains the existing queue and clears the flag first.
The sender then anchors the URB too late, so it is not submitted by
that resume and may remain deferred until another suspend/resume
cycle.

Place the URB on the deferred anchor while txlock is still held, so
the suspend decision and insertion are serialized with the successful
resume path.

This does not change the cleanup performed when resume itself fails.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")

### CO-44

Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED.

The HCI synchronous command path returns -ETIMEDOUT when a command
does not receive a response. It also converts HCI timeout status codes
such as 0x08 and 0x10 to ETIMEDOUT. The MGMT HCI-status table maps
those status codes to MGMT_STATUS_TIMEOUT, so the errno path currently
reports a different result.

For example, if Write Class of Device times out while processing a
Set Device Class, Add UUID or Remove UUID operation, userspace is told
that authentication failed even though no authentication operation
failed.

Map -ETIMEDOUT to MGMT_STATUS_TIMEOUT.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
Cc: stable@vger.kernel.org

---
This changes the MGMT result of a timed-out synchronous command from
0x05 (Authentication Failed) to 0x08 (Timeout). It also makes the
errno path agree with the existing HCI-status table for HCI timeout
statuses and for the case where the controller sends no response.

A BlueZ mgmt-tester case for a timed-out Set Device Class command is
available separately.

### C — only if posted as RFC

Bluetooth: btusb: Avoid QCA9377 runtime suspend on Ryzen while wakeup is needed

An IMC Networks QCA9377 (13d3:3503) attached directly to the xHCI
root hub of a Ryzen 7 5825U system failed to return from one runtime
suspend. The controller did not recover through USB reset or reboot
and returned only after a power cycle.

The failure occurred when the first command after an idle runtime
suspend triggered a resume. The available laptop trace does not
contain the USB-core control-transfer trace needed to show the failed
GET_STATUS directly. The reset timing and USB-core source are
consistent with that path, and the same sequence has been reproduced
with an emulated device which stops answering its resume GET_STATUS.

btusb already uses BTUSB_WAKEUP_BROKEN for devices which cannot safely
runtime-suspend with remote wakeup required. Apply that policy to
13d3:3503 when it is a direct child of a root hub on a Ryzen platform.

This does not disable all runtime suspend of the adapter. It prevents
automatic suspend while the HCI interface requires wakeup; the device
may still suspend after the HCI device is closed.

RFC: this is based on one occurrence on one system and is intended to
determine whether the same failure is seen on other QCA9377/Ryzen
systems.

A small wording point on A: `7bee549e197c` is a particularly plausible `Fixes:` for A as well as E — the original autosuspend support introduced the waker machinery, and later history already identifies that commit as the origin of waker-related lifetime trouble. [Upd.dev](https://upd.dev/torvalds/linux/blame/commit/55cee73e2af555fa3dcff467683c7488af47449e/drivers/bluetooth/btusb.c) I would verify the exact original diff in your full-history tree one last time before adding the tag.

## T7 — emulator

Your `SET_CONFIGURATION` signal is sound **for the limited meaning “the emulated device reached successful post-reset reconfiguration.”** It is not a universal proof that a physical USB reset occurred. USB can issue SET_CONFIGURATION for reasons other than a port reset, and a reset that fails before configuration is restored will never produce it. I would rename the emulator condition/comment from “saw a reset” to something like **“saw post-reset reconfiguration”**.

The missing tests I would implement this way:

| Mode | Implementation |
|---|---|
| D reset lost | Debug-only delay before D's reset work attempts `usb_lock_device_for_reset()`, longer than autosuspend; verify device is suspended and reset work exits without recovery. |
| Reset loses QCA firmware | Add emulator state `patch_loaded` / `nvm_loaded`; clear it on the reset/reconfiguration event; make `QCA_CHECK_STATUS` report unloaded and reject/ignore ordinary HCI traffic until the normal vendor download sequence reloads it. |
| BT-24 | Fault injection in btusb is better than trying to make the USB gadget cause allocation failure: make the first interrupt or bulk RX submission during resume return a selected error, and synchronize a TX sender into the failure window. |
| Leak validation | `CONFIG_DEBUG_KMEMLEAK`; create a deferred command and ACL packet, trigger both `btusb_close()` and failed-resume cleanup separately, then perform repeated kmemleak scans. KASAN/lockdep do not substitute for this. |

For system suspend, I don't see a clean way to make the current vhci setup prove D's system path: vhci itself refuses the suspend, while an in-guest Raw Gadget userspace process is frozen. The credible alternatives are real hardware, a device emulator running *outside* the suspended machine, or a custom QEMU/kernel-space USB device model. I would not invest heavily in that for D now, because the 2013 revert already makes D the wrong generic direction.

### What I would do next

The work now naturally splits.

**A, E, and CO-44 can proceed independently** after final testing/wording. For CO-44 I would refine the BlueZ test so it records that the `WRITE_CLASS_OF_DEV` hook actually fired, then keep the kernel and BlueZ submissions separate.

**BT-18 should become the short USB-core question above.** The 2013 revert plus the very recent restricted Intel reset-resume work make that question considerably stronger than another btusb patch attempt.

**BT-24/BT-25 is probably the next actual btusb patch worth implementing.** It has a source-provable race, source-provable ownership leak, a small coherent fix, and does not depend on solving why the QCA9377 physically wedged.

**T1 should wait for T2's answer.** I would preserve the new `dropcmd-wedge` emulator because it is an excellent regression test, but I would not try to rescue B incrementally. The correct replacement has become a recovery-state-machine problem rather than a PM-predicate tweak.
