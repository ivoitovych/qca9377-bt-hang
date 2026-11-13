# BT-17 patches — outside reviewer 1's review of the intermediate document

*Received 2026-11-13 in answer to `2026-11-13T1100Z-bt17-patches-intermediate-review.md`. The text
is kept as received, except for the reviewer's tooling marks, which `scripts/review-text-clean.py`
removes. What we checked, finding by finding, and the plan that follows are in
`2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`.*

---

**Overall assessment:** The series is carefully reasoned, well-documented, and grounded in a real incident plus an emulation that reproduces the kernel sequence. The defects (BT-17–BT-23) are real, the patches are targeted, and the presentation (full diffs, unpatched context, logs, emulator) is excellent for review. Most are close to ready; a few need tightening before linux-bluetooth.

Findings are marked with patch number and severity (blocker / should-fix / nit). I reviewed primarily from the text plus knowledge of the current USB/btusb code paths; I did not re-apply the series to a tree in this pass.

### Patch 1 (A) — `btusb_waker()` logging
- **Severity:** nit (ready).
- Logging the failure is the right fix. The only previous signal was the later HCI command timeout, which misdirects debugging.
- `-EACCES` is the correct exception: runtime PM is disabled across a system sleep transition, and `btusb_resume()` will drain the deferred URBs when the transition ends. Log level (`bt_dev_err`) is appropriate.
- Minor: consider also treating `-EBUSY` (or other transient codes) if you observe them in practice, but do not block on it.

### Patch 2 (B) — `btusb_reset()` skip condition
Condition: `test_bit(BTUSB_SUSPENDING) && !pm_runtime_active(&intf->dev)`.

- **Severity:** should-fix (wording already noted by you); the logic is mostly sound but the race window needs a comment.
- Reading `pm_runtime_active()` without the PM lock is common in these paths and acceptable here. The function is documented to be racy unless called under the runtime PM lock or when status cannot change. The window is small and the worst case is either an unnecessary skip (rare) or a brief block (the old behaviour). The HCI workqueue racing a USB-core resume is exactly the situation the patch is trying to avoid.
- States that can still pass the check and block in `usb_autopm_get_interface()`:
  - Device has just become active (reset-resume finished, interface marked active) but `BTUSB_SUSPENDING` is still set — this is the case you deliberately want to fall through and reset.
  - Mid-transition where the status flips between the test and the get.
  - Runtime PM disabled (`disable_depth > 0`), which `pm_runtime_active()` treats as active.
- Yes, the “reset-resumed device whose interface is active although `btusb_resume()` never ran” is the primary case where the old reset is still useful (it forces the unbind/rebind that recovers the driver). Other cases are better left to the USB core.
- The known wording issue (message says only “BTUSB_SUSPENDING is set”) is a nit; fix it before sending.

### Patch 3 (D) — `btusb_reset_resume()`
- **Severity:** should-fix (known cost + safety of queueing from the callback).
- Queueing via `usb_queue_reset_device()` from inside a reset-resume callback is allowed by the API (it is explicitly for atomic / deferred contexts and is implemented as a work item on the interface). It will not deadlock on `usb_lock_device_for_reset()` because the actual reset runs later. A disconnect racing the work is handled by the existing “if unbound, skip” logic in the reset path. Still, add a short comment explaining why it is safe and that the work may run after the callback returns.
- The known cost is real: on system resume, devices that already get rebound by `usb_resume_complete()` (the `btusb_needs_reset_resume_table` entries and Realtek devices where `btusb_suspend()` sets `reset_resume` when wakeup is disabled) will now receive one extra USB reset. You could not test system suspend in emulation.
  - Prefer limiting the extra reset to runtime resume if possible (e.g. check `PMSG_IS_AUTO` or the call context), or document the extra reset clearly and accept it only if the recovery benefit outweighs it for those devices.
  - A USB-core fix that also rebinds marked interfaces after a runtime resume (there have been past attempts) would be cleaner long-term, but that is a larger change and not a reason to hold the btusb patch.
- Calling `btusb_resume()` then queueing the reset is the right shape given the missing rebind-on-runtime-resume behaviour.

### Patch 4 (E) — anchor deferred URB under `txlock`
- **Severity:** nit (ready).
- `usb_anchor_urb()` under `spin_lock_irqsave(&data->txlock)` is fine; it does not sleep. The lock order matches what `play_deferred()` already does under the same lock, so no new ordering issue.
- The change correctly closes the race where a resume could clear `BTUSB_SUSPENDING` and drain the anchor between the test and the anchor. With the anchor inside the critical section, `play_deferred()` will still see every URB exactly once.

### Patch 5 (C) — RFC disable runtime suspend of `13d3:3503` on Ryzen root hub
- **Severity:** nit for posting as RFC; should-fix if intended for merge.
- One occurrence is thin, but the failure mode matches the existing MT7922/MT7925 Ryzen root-hub quirk (`dcaf83ead130`) and the device is a direct child of the AMD xHCI root hub. Posting as an RFC is justified; I would not merge it until there is a second occurrence or USB-core debug (dyndbg / usbmon) confirming the same GET_STATUS failure.
- Using the existing `BTUSB_WAKEUP_BROKEN` flag is consistent. The cost (no runtime suspend while the HCI device is open) is acceptable for an RFC.

### CO-44 — MGMT `-ETIMEDOUT` → `MGMT_STATUS_TIMEOUT`
- **Severity:** ready (clear bug fix).
- Mapping `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED` (0x05) is wrong for any non-authentication command. The status is used for HCI command timeouts, connection timeouts reported by the controller, etc. `MGMT_STATUS_TIMEOUT` (0x08) already exists and is the correct mapping (it is what the HCI status table already returns for the various timeout statuses).
- I am not aware of userspace (BlueZ or otherwise) that specifically relies on 0x05 for a timed-out non-auth command; the current mapping causes the misleading “Authentication Failed” logs you observed. A quick search of BlueZ would still be worthwhile before sending.
- `Fixes: 161510ccf91c` looks correct if that is the commit that introduced the current mapping. Yes, it should go to stable.

### Tests / emulator gaps
- The biggest missing path is system suspend/resume (you already noted it). The extra reset on system resume for reset-resume-marked devices is the main untested interaction.
- Emulator differences that matter:
  - Timing of GET_STATUS failure vs real AMD xHCI (the 5 s timeout + retry sequence).
  - No real power loss / USB persist edge cases.
  - No concurrent HCI traffic or SCO during the failure window.
  - The race in Patch 4 was artificially delayed; real timing is tighter but the lock fix is still correct.
- The reproduction of the kernel sequence (timeout → blocked reset → reset-resume or disconnect) is the valuable part and appears solid.

### Series order and readiness
Order is sensible: logging (1) → avoid blocking reset (2) → proper recovery after reset-resume (3) → URB race fix (4) → device-specific RFC (5). The MGMT patch is independent and can go separately or with the series.

Ready for the list after:
- Fix the wording in Patch 2.
- Decide and document (or limit) the extra system-resume reset in Patch 3.
- Keep Patch 5 clearly marked RFC.

The work is high quality. The combination of incident evidence, source reading, and a faithful emulation makes the review much easier than a typical speculative patch series.
