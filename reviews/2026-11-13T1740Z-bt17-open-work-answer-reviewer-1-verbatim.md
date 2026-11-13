# BT-17 open work — outside reviewer 1's answer to the task document

*Received 2026-11-13 in answer to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`. The
text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-13T1750Z-bt17-open-work-answers-checks.md`.*

---

**Review of the 2026-11-13T1740Z open-work document**

The document is a high-quality, self-contained hand-off. The new findings (especially the `dropcmd-wedge` case that kills patch B, and the observation that D’s queued reset can be lost) are important and correctly elevate T1 and T2. The earlier “ready” items (A, E, CO-44) still look solid; the new work is focused on the remaining hard problems.

### T1 — Replacement for patch B (BT-19)

**Requirements analysis**

- (a) Non-blocking on a never-answered runtime resume: essential. The 5+ s GET_STATUS + reset-resume sequence must not stall the ordered HCI workqueue.
- (b) Still reset a device that actually received the command and then autosuspended: the `dropcmd-wedge` case shows the current B condition is too coarse.
- (c) Avoid double-reset after a successful core reset-resume: still desirable.
- (d) Avoid a racy `pm_runtime_active()` snapshot: agreed; the function’s own documentation says the result is only trustworthy under the PM lock or when status cannot change.

**Proposed sketch (meets a–d)**

Hand the actual USB reset to a separate work item that is *not* on `hdev->workqueue`. `hci_cmd_timeout()` still calls a lightweight `btusb_reset()` that only decides and queues; the credit is restored promptly.

```c
/* in btusb_data */
struct work_struct reset_work;

static void btusb_reset_work(struct work_struct *work)
{
    struct btusb_data *data = container_of(work, struct btusb_data, reset_work);
    /* optional: usb_autopm_get_interface() here if you want to wait for a
       live resume; or just queue the reset and let the core handle it */
    usb_queue_reset_device(data->intf);
}

static void btusb_reset(struct hci_dev *hdev)
{
    struct btusb_data *data = hci_get_drvdata(hdev);
    unsigned long flags;
    bool on_deferred;

    spin_lock_irqsave(&data->txlock, flags);
    on_deferred = !usb_anchor_empty(&data->deferred);
    spin_unlock_irqrestore(&data->txlock, flags);

    /* (b) + (a): if the command never left the deferred anchor, it never
       reached the controller. The USB core already owns the resume failure. */
    if (on_deferred)
        return;

    /* otherwise the transfer completed (or was in flight) — the device
       saw the command and we may need a USB reset */
    schedule_work(&data->reset_work);
}
```

- Test for “never reached the controller”: `!usb_anchor_empty(&data->deferred)` under `txlock` is a good first approximation for the BT-17 case. A URB can still be in flight (submitted, not yet completed) while the device is suspending; that is rarer for the timeout path but possible. Checking the in-flight count or the specific URB’s status would be more precise, but the deferred-anchor test already covers the dominant failure mode you observed.
- Mechanism: a separate work item is cleaner than `pm_runtime_get_if_active()` or `usb_autopm_get_interface_async()` inside the HCI workqueue. The latter two still risk blocking or racing.
- Credit: restored as soon as `btusb_reset()` returns, so queued commands are not artificially delayed. That matches the current contract.
- Cost: in the pure BT-17 case you may see multiple `tx timeout` lines instead of one long stall. That is preferable to a 5 s workqueue stall and should be acceptable to the Bluetooth maintainers (the alternative is worse).

This sketch satisfies (a)–(d) on the cases described. It still needs the `dropcmd-wedge` and `recover` scenarios re-run.

### T2 — BT-18 question for USB maintainers

**Intent.** The asymmetry looks unintentional. `usb_resume_interface()` sets `needs_binding` when the driver has no `reset_resume`, and `usb_resume_complete()` → `rebind_marked_interfaces()` only runs on system resume. Runtime resume never does the rebind. The `autosuspend_check()` gate that refuses autosuspend for `USB_QUIRK_RESET_RESUME` devices without a `reset_resume` callback is the core’s attempt to avoid the problem; a failed runtime resume that then takes the persist/reset-resume path bypasses that gate. There were earlier linux-usb patches (2014-era Loic Poulain series) that tried to schedule a rebind work item after runtime resume; they never landed.

**Fix.** The cleanest core change is a deferred unbind/rebind (work item, same pattern as `usb_queue_reset_device()`) when a runtime resume leaves any interface with `needs_binding` set. Doing it inline is ruled out by the device-lock requirements and the fact that the runtime resume path may already hold the lock depending on the call chain (remote wakeup vs local). Failing the resume outright is harsher than necessary.

**Or btusb.** A proper `reset_resume` that re-runs vendor setup (QCA rampatch) while holding HCI traffic and a PM reference is possible, but it is more work and still leaves the general “driver without reset_resume + runtime reset-resume” hole open for other drivers. Prefer the core fix; a btusb-side `reset_resume` is a reasonable interim if the core change is slow.

**Draft mail (short, factual):**

```
Subject: USB: interfaces marked needs_binding after a runtime reset-resume are never rebound

When a runtime resume fails and USB persist triggers a reset-resume,
usb_resume_interface() sets needs_binding if the driver has no
reset_resume callback. rebind_marked_interfaces() is only called from
usb_resume_complete() (system resume) or from usb_reset_device().
After a pure runtime resume the interface stays bound, never resumed.

Seen with btusb (no reset_resume) on a QCA9377 that did not answer
GET_STATUS: after the core’s reset-resume the device answered USB
requests but Bluetooth stayed dead (BTUSB_SUSPENDING never cleared,
all later URBs parked on the deferred anchor) until unplug or reboot.

Is the missing rebind on the runtime path intentional? Would a
deferred unbind/rebind (work item, analogous to usb_queue_reset_device)
after a runtime resume that left needs_binding set be acceptable?
```

### T3 — BT-24 and the suspected leak

Both observations look correct from the source.

- The `failed:` path in `btusb_resume()` does `usb_scuttle_anchored_urbs(&data->deferred)` without `txlock`, then clears `BTUSB_SUSPENDING` under the lock. A concurrent `submit_or_queue_tx_urb()` can still see the flag and anchor a URB that is then never played. This is a real race; how often the interrupt/bulk submit fails at resume depends on the host controller and device state, but the window exists.
- `usb_scuttle_anchored_urbs()` only unanchors and drops the anchor reference. It does not free the `skb` (`urb->context`) or the control setup packet. The same is true of the scuttle in `btusb_close()`. `play_deferred()`’s cleanup frees the setup packet but not the skb. So both scuttle paths leak those objects.

**Suggested fix (covers both the race and the leak):** under `txlock`, drain the deferred anchor with the same cleanup `play_deferred()` already does, plus `dev_kfree_skb_any()` for the skb, then clear the flag. Completing the HCI commands with an error (rather than silently dropping them) is preferable if the call chain allows it; at minimum the resources must be freed.

### T4 — No recovery while HCI Reset is pending

The observation matches the code: `hci_cmd_work()` skips arming `cmd_timer` when `HCI_RESET` is set. Consequently a power-on HCI Reset that times out never reaches `hdev->reset()`. This appears intentional (avoid recursive reset while a reset is already in progress) but has the side-effect you describe. Whether a failed power-on Reset should still invoke the driver’s recovery path is a policy question for the Bluetooth maintainers; it is not obviously a bug, but it does leave a wedged controller unrecovered until unplug/reboot. No recent linux-bluetooth discussion turned up in a quick search.

### T5 / T6 / T7 (brief)

- Prior art: the 2014 runtime-rebind patches on linux-usb are the closest prior art for T2. No evidence that the `-ETIMEDOUT` → `MGMT_STATUS_AUTH_FAILED` mapping was a deliberate choice for non-auth commands.
- Wording: the points you listed for A, E, CO-44 and C are accurate; the suggested adjustments make the messages tighter and more precise.
- Emulator: `--wedge-until-reset` looking for SET_CONFIGURATION is a reasonable proxy on vhci; a real xHCI reset sequence is more complex, but it is sufficient for the tests you are running. The missing modes you listed (especially delayed reset work and system-suspend variants) are the right next additions.

**Bottom line.** A, E and CO-44 remain ready. B must be replaced (T1 sketch above is a starting point that satisfies the four requirements). D should not be sent as a fix; the right next step is the linux-usb question in T2. T3 is a clear, fixable defect. The document is in excellent shape for parallel outside review.
