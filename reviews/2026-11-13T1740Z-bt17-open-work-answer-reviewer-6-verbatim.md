# BT-17 open work — outside reviewer 6's answer to the task document

*Received 2026-11-13 in answer to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`. The
text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-13T1750Z-bt17-open-work-answers-checks.md`.*

---

Fetching the open-work document now.

I did T5 first because the history changes T1 and T2, then the design, source and wording tasks. Source checks are against mainline master as fetched today, not `da3cc0258`, so I give function names instead of line numbers. Nothing was run, and every sketch is uncompiled.

## T5: prior art

**CO-43**
- **Lost queued reset.** Jiajia Liu's August 2026 patch put a `usb_autopm_put_interface()` right after `usb_queue_reset_device()` in `btusb_reset()`, and he withdrew it two hours later because a device that suspends first makes `usb_lock_device_for_reset()` abort the reset. Later revisions through v5 keep the reference under a `BTUSB_RESET` flag instead. That is reviewer 7's finding 14, already accepted on-list. I read these on a list mirror I don't know (ratatoskr.run), so confirm on lore.
- **D's gate hazard has happened before.** Kai-Heng Feng's 2018 revert of the QCA Rome reset-resume fix says the USB reset landed in `btusb_open()` and interrupted firmware loading. Hans de Goede's DMI-table commit notes that the reset-resume quirk also turns runtime suspend off.
- **Realtek relies on the missing callback.** In the 2020 thread Kai-Heng describes the core calling probe because btusb has no `reset_resume`, and Realtek's Alex Lu states the design as "btusb will reprobe after resume". Running `btrtl_setup_realtek()` from `btusb_resume()` was floated there; mainline has no such call.
- **The asymmetry is known.** Johan Hovold's 2016 revert message says a runtime resume, unlike a system resume, ignores `needs_binding`. Alan Stern asked in reply whether `usb_runtime_resume()` honouring the flag would help, and doubted it for that case. I found no follow-up.
- **Stated core intent.** Alan's 2014 "unbind all interfaces before rebinding any" describes unbind-then-rebind for drivers without the callbacks after a reset or a reset-resume, with no runtime exception.
- **A warning for a work-item fix.** An August 2026 RFC by Hongyu Xie also unbinds and rebinds marked interfaces from deferred work. Oliver Neukum objected to the system workqueue for work that allocates with GFP_KERNEL, and Alan rejected the idea overall, for system-resume reasons.
- **Overlapping pending patch.** Sean Rhodes's "clear remote wake on idle Intel ACPI paths" changes `play_deferred()` and `btusb_resume()`. I don't know its status; it will conflict with E and any BT-24 fix.

**CO-44**
- The 2021 RFC of `161510ccf91c` carries no explanation for the mapping, in the message or the thread overview. I did not read the v2–v4 threads.
- Luiz's own `bt_status()` came in April 2022. In mainline `lib.c` it maps `-ETIMEDOUT` to 0x08, which the table maps to `TIMEOUT`. That belongs in the note.
- User reports pair the 0x05 text with command timeouts: ubuntu-fr, 2023, for Set Device Class and Add UUID beside `0x0c24` failing `-110`; the ath11k list, 2024, on a QCA6390; a NixOS issue opened 7 November on an RTL8761BU.
- An ArchWiki user page treats these errors on Realtek adapters as an authentication problem, which is the misdirection your message describes.

**Not found:** later patches to `mgmt_errno_status()`, and MGMT users outside bluetoothd that branch on 0x05 or 0x08 (one search each). **Not searched:** linux-usb's RFC conventions.

## T1: replacing B

- **New, should-fix (source): `hdev->reset` has a second caller.** `reset_store()` in `hci_sysfs.c` calls it from user space. It was proposed in January 2025 to recover unresponsive devices from user space. So B also refuses a manual reset of a suspended device, and "nothing ever resets it" means nothing in the kernel. Check that `da3cc0258` has it.
- **The test is right, with one hole.** An in-flight TX URB keeps `tx_in_flight` up, and `btusb_suspend()` refuses autosuspend then. With one command credit, a non-empty `deferred` at the timeout holds the timed-out command. Not sure: vendor commands from a raw socket bypass the credit and could sit there instead.
- **Mechanism: your own work item with a synchronous get.**
  - `usb_autopm_get_interface_async()` plus the queued reset is the lost-reset race again.
  - `pm_runtime_get_if_active()` on the interface reports "does anyone hold a reference", and on the device it cannot resume a suspended one.

```c
static void btusb_reset_work(struct work_struct *work)	/* not on hdev->workqueue */
{
	struct btusb_data *data = container_of(work, struct btusb_data, reset_work);
	int err;

	err = usb_autopm_get_interface(data->intf);	/* may wait for a resume */
	if (err) {
		bt_dev_err(data->hdev, "Failed usb_autopm_get_interface: %d", err);
		return;
	}
	if (test_and_set_bit(BTUSB_RESET, &data->flags))
		usb_autopm_put_interface_no_suspend(data->intf);
	bt_dev_err(data->hdev, "Resetting usb device.");
	usb_queue_reset_device(data->intf);
}

static void btusb_reset(struct hci_dev *hdev)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	unsigned long flags;
	bool parked;

	spin_lock_irqsave(&data->txlock, flags);
	parked = test_bit(BTUSB_SUSPENDING, &data->flags) &&
		 !usb_anchor_empty(&data->deferred);
	spin_unlock_irqrestore(&data->txlock, flags);

	if (parked) {
		bt_dev_warn(hdev, "Command not sent yet (device resuming); not resetting");
		return;
	}
	schedule_work(&data->reset_work);
}
```

Add `INIT_WORK` in probe and `cancel_work_sync()` in `btusb_disconnect()` after `hci_unregister_dev()`. It needs E first, so the anchoring is under `txlock`.

| Case | Result |
|---|---|
| BT-17 dead | parked, no stall (a) |
| `dropcmd-wedge` | not parked, work resumes and resets (b); if that resume hangs, it hangs off the HCI queue |
| awake wedge with connections | as today |
| system sleep | `-EACCES`, logged |
| sysfs reset | works |
| `recover` | parked, so no btusb reset, and BT-18 must be fixed first |

- **(c) cannot be met inside btusb.** A rebind there costs a USB reset; only the core can rebind without one.
- **(d)** holds: no PM status is read.
- **Credit:** unchanged in practice, because the reset itself was always asynchronous.
- **Three timeout lines:** acceptable in my reading; not sure of Luiz's.

## T2: BT-18

- **Intent:** not designed, and known since 2016. The `autosuspend_check()` gate covers only reset-resumes known in advance.
- **Why not inline (source):** `usb_unbind_interface()` starts with `usb_autoresume_device()`, which would wait on the resume it is called from. The unbind also needs the device lock, which runtime resume may or may not hold.
- **Core options:**
  - a deferred `usb_unbind_and_rebind_marked_interfaces()` with a PM reference and the device lock, on a queue that tolerates allocation;
  - failing such a resume, so the port is logically disconnected and re-enumerated. That is simpler but costs one more reset.
- **A btusb fallback without D's side effects (new, untested):** keep btusb without `reset_resume`, and detect the state where btusb already holds a reference: after a successful get in `btusb_waker()`, `btusb_open()` and `btusb_close()`.

```c
/* Caller holds a PM reference. */
static void btusb_check_missed_resume(struct btusb_data *data)
{
	if (!data->intf->needs_binding)	/* or: BTUSB_SUSPENDING still set */
		return;
	if (!test_and_set_bit(BTUSB_RESET, &data->flags))
		usb_autopm_get_interface_no_resume(data->intf);
	usb_queue_reset_device(data->intf);
}
```

  - It opens no autosuspend gate, changes nothing at system resume, and cannot lose the reset.
  - It still pays the second reset.
  - It reads a core-owned field; the `BTUSB_SUSPENDING` variant avoids that but can misfire during a system suspend. Not sure which Alan prefers.
  - A resume started by remote wakeup is caught only at the next TX.

**The mail** (linux-usb; Cc Alan Stern, Greg KH, Oliver Neukum, linux-bluetooth, Luiz):

```
Subject: usb: core: no rebind after a runtime reset-resume for drivers without reset_resume

When a runtime resume fails its GET_STATUS and persist is enabled,
finish_port_resume() retries as a reset-resume. For an interface whose
driver has no reset_resume, usb_resume_interface() sets needs_binding
and skips the driver. usb_resume() unbinds marked interfaces and
usb_resume_complete() rebinds them, but usb_runtime_resume() only calls
usb_resume_both(). The driver stays bound and is never resumed again:
every later resume skips it because needs_binding is still set.

Seen with btusb (supports_autosuspend, no reset_resume) on
bluetooth-next da3cc02587c6, with usbip and an emulated device that
holds the first GET_STATUS after a resume:

  usb 2-1: usb auto-resume
  usb 2-1: retry with reset-resume
  usb 2-1: reset full-speed USB device number 2 using vhci_hcd
  btusb 2-1:1.0: no reset_resume for driver btusb?
  usb 2-1: usb auto-suspend, wakeup 1
  usb 2-1: usb auto-resume
  Bluetooth: hci0: Opcode 0x0c03 failed: -110

autosuspend_check() keeps USB_QUIRK_RESET_RESUME devices out of
autosuspend when a driver lacks reset_resume, but a reset-resume forced
after a failed resume does not pass through it.

1. Is the missing rebind after a runtime reset-resume intended?
   (Noted in 2016: <link to Johan Hovold's revert>.)
2. If not: defer usb_unbind_and_rebind_marked_interfaces() to a work
   item holding a PM reference and the device lock? It cannot run
   inline, since the unbind resumes the device it is called from.
3. Or fail such a resume, so that the device is re-enumerated?
4. Or must the driver provide reset_resume? btusb's Realtek path
   relies on the rebind.
```

## T3: BT-24 and the leak

- **The leak is real (source, should-fix).** `usb_scuttle_anchored_urbs()` only unanchors. `urb_destroy()` frees a transfer buffer only with `URB_FREE_BUFFER`, which these URBs lack. So `btusb_close()` and `failed:` leak the skb and the setup packet, and `play_deferred()` leaks the skb in both its failure branch and its cleanup loop.
- **BT-24 is right but nearly moot (nit).** The submission fails on `-ENODEV`, `-ESHUTDOWN` or `-ENOMEM`, and in each case Bluetooth is dead anyway. The stranded URB then leaks at close.
- **One fix for both, after E:** clear the flag under `txlock` first, then drain outside the lock.

```c
static void btusb_free_deferred(struct btusb_data *data)	/* process context */
{
	struct urb *urb;

	while ((urb = usb_get_from_anchor(&data->deferred))) {
		kfree(urb->setup_packet);
		kfree_skb(urb->context);
		usb_free_urb(urb);
	}
}
```

  - Call it at `failed:`/`done:` after the unlock, after the success path's unlock, and in `btusb_close()`.
  - Drop `play_deferred()`'s second loop, and use `dev_kfree_skb_any()` in its failure branch.
  - The `done:` path today leaves stale URBs to be played at a later resume.
- **Completing with an error:** `hci_cmd_sync_cancel()` at `failed:` would mirror `btusb_tx_complete()`. Not sure it is worth it.

## T4: HCI Reset and the timer

- **The timer exemption is intended; the missing recovery is not.** Szymon Janc's commit `7bdb8a5cf17f` fixed a regression on chips with a slow reset, such as CSR, where the next command went out before the reset finished; it dates from July 2011. From memory, not searched: the driver reset hook came years later, so nobody chose "no recovery".
- **A fix belongs on the sync side, not the timer:** call `hdev->reset` when HCI Reset or init fails with `-ETIMEDOUT`. Risk: a reset loop at power-on. Not sure the maintainers want it, since the sysfs attribute hands this to user space.

## T6: wording

```
Bluetooth: btusb: Log a failed resume for deferred data

When data is sent while the device is runtime suspended,
submit_or_queue_tx_urb() parks the URB on data->deferred and
btusb_waker() resumes the device. If that resume fails, the waker
returns silently and the URB stays parked. A command in it then ends
in an HCI command timeout, which points at the controller.

Log the error. -EACCES is left out: it is returned while runtime PM is
disabled, as it is during a system sleep transition.
```
Code comment: `/* -EACCES: runtime PM is disabled, e.g. during system sleep */`.

```
Bluetooth: btusb: Anchor a deferred URB under txlock

submit_or_queue_tx_urb() tests BTUSB_SUSPENDING under txlock, drops the
lock, and then anchors the URB on data->deferred. btusb_resume() plays
the deferred URBs and clears the flag under txlock. A resume that
completes in between leaves the URB anchored on an active device: the
waker has nothing to resume, and the URB waits for the next resume. A
command in it times out.

Anchor the URB in the critical section that tests the flag.
btusb_resume() already takes the anchor's lock inside txlock, so the
lock order does not change.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
```

```
Bluetooth: MGMT: Report a timed out command as MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED. The
sync command path returns -ETIMEDOUT when the controller does not
answer, and for the HCI statuses that bt_to_errno() maps to ETIMEDOUT.
None is an authentication failure, and mgmt_status_table[] reports
those statuses as MGMT_STATUS_TIMEOUT.

A controller that stops answering therefore makes Set Powered, Add
UUID or Set Device Class fail with "Authentication Failed (0x05)".

Return MGMT_STATUS_TIMEOUT.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
---
User-visible: a timed-out MGMT command completes with 0x08, not 0x05.
bt_status(-ETIMEDOUT) is 0x08 and mgmt_status_table[0x08] is TIMEOUT,
so this makes the errno path agree with both. I found no reason for
the old value in 161510ccf91c; if it was deliberate, please say.
No Cc: stable from me, since the value is visible to user space.
```
On stable: `Fixes:` alone usually gets it picked, so the note must say you leave it to him.

For C: subject "Bluetooth: btusb: Set BTUSB_WAKEUP_BROKEN for QCA9377 13d3:3503 on Ryzen", marked RFC. The body's second sentence should read: "The failed GET_STATUS is inferred from the USB core's code and reproduced with an emulated device; the machine's log shows only the command timeout and the resets."

## T7: emulator

- **Reset signal:** sound for vhci. Fakes: `usb_reset_configuration()`, a usbfs or sysfs configuration write, and the re-enumeration after a logical disconnect. Hides: a reset that fails before SET_CONFIGURATION. Pairing it with the preceding 64- or 8-byte device-descriptor read is sharper. A real chip unwedges at the bus reset itself, which usbip cannot show.
- **(a)** needs a debug-only delay in `__usb_queue_reset_device()` plus a short autosuspend delay; expect `-EHOSTUNREACH` and no rebind.
- **(c)** detach the emulated device during the resume to get `-ENODEV`, with a bt23-style delay.
- **(d)** the A+B `bt17` run should leak three skbs and three 8-byte setup packets at disconnect.
- **System suspend (untested idea):** run the emulator outside the guest. Raw Gadget on `dummy_hcd` on the host or an outer VM, passed in with `-device usb-host` on `qemu-xhci`, then `pm_test=devices` in the guest with `usbcore.quirks=13d3:3503:b`. The freezer no longer stops the device, and you get a real xHCI path.

## Corrections to section 4

- **Finding 7:** the `failed to resubmit (2)` line is not D's. The NixOS report shows it beside repeated "Resetting usb device" on a stock 6.18 kernel.

Sources:
- [Johan Hovold's 2016 revert, with Alan Stern's reply](https://lkml.iu.edu/hypermail/linux/kernel/1605.0/00563.html)
- [Jiajia Liu, btusb_reset PM reference, first posting and withdrawal](https://ratatoskr.run/linux-arm-kernel/2026/08/17427486/t)
- [Revert "Bluetooth: btusb: fix QCA Rome suspend/resume"](https://lkml.iu.edu/hypermail/linux/kernel/1802.1/06319.html)
- [Bluetooth: btusb: Avoid unnecessary reset upon system resume (2020 thread)](https://lkml.indiana.edu/2009.3/01584.html)
- [Bluetooth: Don't use cmd_timer to timeout HCI reset command](https://android-kvm.googlesource.com/linux/+/7bdb8a5cf17f66614a9897645efcd4ccc27535ee)
- [RFC 3/5, hci_sync: Make use of hci_cmd_sync_queue set 1](https://lore.kernel.org/all/20210528000136.52352-3-luiz.dentz@gmail.com/)
- [RFC: usb: core: defer leaf-device resume off the S3 critical path](https://ratatoskr.run/linux-usb/2026/08/17369900/t)
- [NixOS/nixpkgs #584582](https://github.com/NixOS/nixpkgs/issues/584582)
