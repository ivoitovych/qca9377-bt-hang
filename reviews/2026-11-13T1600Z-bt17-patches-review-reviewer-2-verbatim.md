# BT-17 patches — outside reviewer 2's review of the intermediate document

*Received 2026-11-13 in answer to `2026-11-13T1100Z-bt17-patches-intermediate-review.md`. The text
is kept as received, except for the reviewer's tooling marks, which `scripts/review-text-clean.py`
removes. What we checked, finding by finding, and the plan that follows are in
`2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`.*

---

# **Technical review — BT-17 / CO-43 / CO-44**

**Review date:** 13 November 2026\
**Target:** `bluetooth-next` at `da3cc0258`, BlueZ at `20ffd285b`\
**Scope:** Five btusb patches, one kernel MGMT patch, one BlueZ regression test.

I have read the [intermediate review dossier](https://raw.githubusercontent.com/ivoitovych/qca9377-bt-hang/main/reviews/2026-11-13T1100Z-bt17-patches-intermediate-review.md), including the patch diffs, baseline source excerpts, USB-core execution paths, and emulator results.

## **Overall assessment**

The investigation has identified real, independently useful problems. In particular, the successful-reset-resume failure (BT-18), the HCI workqueue blocking (BT-19), and the deferred-URB race (BT-23) deserve upstream attention.

However, **I would not submit CO-43 as one five-patch series in its present form.** The patches have different maturity levels, and the reset-resume recovery mechanism carries substantial risks outside the emulated runtime-PM scenario.

| Patch                        | Severity    | Preliminary disposition                       |
| ---------------------------- | ----------- | --------------------------------------------- |
| 1 — A, failed-resume logging | Nit         | Good, minor refinement                        |
| 2 — B, skip blocked reset    | Should-fix  | Race and state-handling review needed         |
| 3 — D, reset-resume recovery | **Blocker** | Redesign or further validation                |
| 4 — E, deferred-URB race     | Should-fix  | Strong standalone candidate                   |
| 5 — C, Ryzen workaround      | Should-fix  | RFC only; not ready to merge                  |
| CO-44, MGMT status           | Nit         | Strong standalone candidate                   |
| BlueZ regression test        | Should-fix  | Good approach; test behavior needs refinement |

The most important distinction is between **fixing the behavior after a resume failure** and **preventing the original controller hang**. The first is demonstrable in emulation. The second remains a hardware/firmware/platform question, and the dossier appropriately avoids claiming otherwise.

## **1. Patch 2 (B): the reset-suppression condition is not sufficient**

SHOULD-FIX · Source-checked

The patch introduces:

```
if (test_bit(BTUSB_SUSPENDING, &data->flags) &&
    !pm_runtime_active(&data->intf->dev)) {
    bt_dev_err(hdev, "Device not resumed; not resetting");
    return;
}
```

This works for the failure reproduced by the emulator, but I see two separate problems.

### **Finding B1 — The timed-out command may already have reached the controller**

**This is the most important missing scenario for patch B.**

The commit message asserts that the command which timed out never reached the controller because `BTUSB_SUSPENDING` is set.

That is true for the particular BT-17 reproduction. It is **not a general invariant**.

In `btusb_tx_complete()`, `tx_in_flight` is decremented when the USB URB completes, not when the corresponding HCI Command Complete event arrives.

A possible sequence is:

1. An HCI command is successfully transmitted over USB.
2. Its USB URB completes and `tx_in_flight` becomes zero.
3. The controller fails to return the HCI completion.
4. Runtime suspend begins and sets `BTUSB_SUSPENDING`.
5. The HCI command timer expires.
6. Patch B suppresses the controller reset, even though the command really was transmitted.

That is an important behavioral change. The HCI timeout may reflect a genuinely unresponsive controller rather than merely an outstanding runtime resume.

**Required test:** Make the emulator accept a command's USB transfer, suppress its HCI Command Complete, permit runtime suspend, and then trigger the HCI timeout. Compare reset behavior before and after patch B.

I would not describe the patch as generally safe until this case is understood.

### **Finding B2 — The runtime-PM state check is not synchronization**

`pm_runtime_active()` is a state query, not an operation that acquires a PM reference or stabilizes the device state.

It does not guarantee that the state remains unchanged between the condition and `usb_autopm_get_interface()`.

There are at least three situations to distinguish:

| Observed situation                                      | Potential outcome                                      |
| ------------------------------------------------------- | ------------------------------------------------------ |
| Interface suspended or resuming, flag set               | Reset is skipped                                       |
| Interface active, flag still set                        | Existing reset path is taken                           |
| Interface becomes suspended immediately after the check | `usb_autopm_get_interface()` may still wait for resume |

The last situation matters because it means the patch does not completely eliminate the original workqueue-blocking problem.

The second is deliberately supported for the BT-18 recovery path without patch D, but it also admits other stale or transitioning states.

I would prefer an explicit driver state or coordinated state transition, rather than interpreting two independently changing values as proof that recovery is already underway.

**Recommendation:** Keep patch B experimental until B1 is tested and B2 is either addressed or its residual race documented and accepted.

## **2. Patch 3 (D): reset-resume recovery**

BLOCKER · Source-checked

This is the patch I would change most substantially.

### **Finding D1 — The queued reset is not inherently unsafe**

The implementation is:

```
err = btusb_resume(intf);
if (intf == data->intf)
    usb_queue_reset_device(intf);

return err;
```

The USB core's `usb_queue_reset_device()` schedules work and takes an interface reference. Its worker subsequently calls `usb_lock_device_for_reset()`.

This is a valid mechanism for requesting a reset asynchronously. The USB core explicitly supports deferred resets and handles an interface that was unbound before the worker could perform its operation.

I therefore **do not identify an immediate use-after-free or lock-inversion defect merely from calling this function inside**`reset_resume()`.

That conclusion is narrower than claiming the recovery design is safe.

### **Finding D2 — Normal resume processing is performed on a reset controller**

The larger problem is that `btusb_resume()` is not merely housekeeping.

It may:

- Resubmit interrupt and bulk URBs.
- Execute a vendor-specific resume callback.
- Submit deferred HCI traffic through `play_deferred()`.
- Clear `BTUSB_SUSPENDING` and schedule additional work.

All this happens before the queued USB reset and subsequent driver reinitialization.

But `reset_resume` specifically means that the USB device has been reset during resume. Its previous Bluetooth controller state may no longer exist.

Consequently, the patch can temporarily make the old HCI instance operational against a controller whose firmware or HCI state requires complete initialization.

For example, deferred commands may be sent during the interval between the callback returning and the reset worker unbinding btusb.

Even if that interval is brief, it is a real behavior change.

**The recovery path should not expose the transport as operational before the driver has recovered its state.**

### **Finding D3 — System resume introduces a broad regression risk**

The dossier correctly identifies that certain devices intentionally use reset-resume during system sleep.

These include entries from `btusb_needs_reset_resume_table` and affected Realtek devices.

Currently, their recovery may depend on the USB core rebinding the interface after system resume.

Patch D substitutes an ordinary btusb resume followed by another USB reset and rebinding.

That means two concerns arise simultaneously: an unnecessary additional reset, and temporary use of a controller before its expected reinitialization.

The emulator's inability to exercise system suspend leaves this entirely unvalidated.

I consider this a **submission blocker**, not merely a missing performance benchmark.

### **Finding D4 — A failed**`btusb_resume()`**still queues another reset**

Even if `btusb_resume()` returns an error, patch D schedules the reset.

This may ultimately be desirable, but the policy needs to be deliberate. A resume error can indicate an inaccessible USB device, a failed URB submission, or an incomplete multi-interface resume.

The series should explicitly test the error case rather than allowing it to follow the success case automatically.

### **Preferred direction**

My preference is to investigate fixing **the runtime reset-resume rebinding behavior in USB core**, because the specific BT-18 failure arises from the difference between runtime and system resume handling of `needs_binding`.

That should be presented to USB maintainers as a separate question, with the reproduced BT-18 scenario.

A smaller btusb-specific solution could be acceptable, but it should defer recovery without first restarting ordinary HCI traffic, avoid unnecessary system-resume resets, and preserve correct suspend accounting.

I would not choose a guard based solely on `pm_runtime_active()` to distinguish system from runtime resume. The callback needs a reliable indication of the operation being performed.

## **3. Patch 4 (E): deferred-URB race**

SHOULD-FIX · Source-checked

This is the strongest btusb correctness patch of the group.

Originally, the code decides whether to defer an URB while holding `txlock`, but adds the URB to the deferred anchor after releasing that lock.

Meanwhile, `btusb_resume()` calls `play_deferred()` and clears `BTUSB_SUSPENDING` while holding the same `txlock`.

The race is straightforward:

**TX thread**

Original implementation

**Resume thread**

Original implementation

Reads SUSPENDING = 1

Waiting for txlock

Releases txlock

Drains deferred URBs and clears flag

Anchors URB too late

Resume already finished

Moving `usb_anchor_urb()` into the critical section closes this particular window.

The USB anchoring operation is appropriate under a spinlock, and `play_deferred()` already acquires the anchor locks while holding `txlock`. I see no new obvious lock-order inversion in this change.

The debug-delay experiment is good supporting evidence, although it is not proof of the natural race's frequency.

**Recommendation:** Separate E from the recovery series, preserve the focused reproduction test, and consider submitting it independently after one final locking and disconnect stress test.

I would also test a suspend attempt occurring immediately after URB submission, to demonstrate that the existing `tx_in_flight` protection remains intact.

## **4. Patch 1 (A): failed-resume diagnostics**

NIT · Source-checked

Logging the return value of `usb_autopm_get_interface()` is reasonable. BT-17 demonstrates why this diagnostic matters: a Bluetooth HCI timeout can be merely the downstream consequence of USB runtime resume failure.

The `-EACCES` exception is also defensible because it can be returned when runtime PM is disabled during system sleep transitions.

However, `-EACCES` does not exclusively identify that situation. Suppressing it unconditionally could conceal a persistent configuration or PM-state problem.

I suggest making the exception explicit in the commit explanation, possibly retaining debug-level logging for `-EACCES`.

For other errors, error-level logging is reasonable, although repeated failures can generate multiple messages per incident. Rate limiting might be worthwhile if maintainers object to log noise.

**Verdict:** No substantive correctness objection. This is suitable for an independent small patch.

## **5. Patch 5 (C): Ryzen / QCA9377 workaround**

SHOULD-FIX · Source and evidence review

I agree with the dossier's decision to treat this as an RFC.

The comparison to `dcaf83ead130`, covering MediaTek devices on Ryzen platforms, is useful. However, the demonstrated mechanism is not identical.

The MediaTek workaround addresses reported remote-wakeup failures. In BT-17, the command appears to have initiated a host-driven resume.

The proposed code would prevent runtime suspend in the affected configuration, thereby avoiding the trigger. But this does not establish that the underlying defect is caused by the same Ryzen USB wakeup behavior.

The emulator result demonstrates that the condition disables autosuspend in the intended environment. It does **not** demonstrate that the hardware failure mechanism is correctly identified.

There is also a meaningful power-management cost: the device may remain active whenever the HCI interface is open.

I would retain C as an RFC, separate from A/B/D/E, with the following distinction stated prominently:

*This is a proposed mitigation for an observed failure, not an identified correction of the failure's root cause.*

For stronger evidence, I would want a recurrence with USB-core logging enabled, a controlled comparison with autosuspend disabled, and ideally a second affected machine.

The laptop does not need to be exposed to additional experimental failures merely to make the other patches upstream-ready.

## **6. CO-44: correct MGMT timeout classification**

NIT · Independently checked against upstream history

This is a strong patch.

The existing mapping is:

```
case -ETIMEDOUT:
    return MGMT_STATUS_AUTH_FAILED;
```

The proposed correction is:

```
case -ETIMEDOUT:
    return MGMT_STATUS_TIMEOUT;
```

The MGMT protocol explicitly defines both statuses, with different meanings: authentication failure is `0x05`, and timeout is `0x08`.

Bluetooth Management Protocol documentation+1



### **Finding CO44-1 — The Fixes tag is correct**

I independently examined upstream commit [161510ccf91c](https://github.com/torvalds/linux/commit/161510ccf91c).

It introduced `mgmt_errno_status()` and the incorrect `-ETIMEDOUT` mapping on 27 October 2021.

Therefore the proposed tag:

```
Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
```

is justified.

### **Finding CO44-2 — The status correction has a clear semantic basis**

An HCI command that receives no response is not automatically an authentication failure.

The test's Write Class of Device command is a particularly good example, because no authentication procedure is involved.

The change is also consistent with existing HCI-to-MGMT mappings for timeout statuses.

I found no convincing reason to retain the incorrect classification.

The only caveat is that `mgmt_errno_status()` is a shared conversion function. The change affects more callers than Set Device Class and Remove UUID. An external userspace application could conceivably have learned to interpret `0x05` as a generic timeout.

That is a compatibility consideration, not a reason to preserve the bug. The dossier's BlueZ audit substantially reduces this concern, although it cannot prove that no third-party client depends on the old behavior.

### **Finding CO44-3 — Stable backport**

I consider this a reasonable stable-backport candidate after upstream acceptance.

The defect dates to 2021, the change is minimal, and the regression test shows a clear before/after distinction.

Nevertheless, since the observable MGMT status changes, I would leave the final stable decision to the Bluetooth maintainers rather than treat it as automatically risk-free.

## **7. BlueZ regression test**

SHOULD-FIX · Source and test-log review

The test is well targeted.

It intercepts `BT_HCI_CMD_WRITE_CLASS_OF_DEV`, prevents the emulator from answering, and checks the resulting MGMT completion.

UNPATCHED KERNEL

# **0x05**

Test fails

Authentication Failed

PATCHED KERNEL

# **0x08**

Test passes

Timeout

The supplied evidence reports all 527 mgmt-tester cases passing with the kernel change, compared with 526 passing and the new case failing without it.

I have one improvement request: make sure the test explicitly verifies that the hook actually intercepted the intended command, rather than relying exclusively on the eventual timeout status. This would make the regression test more robust against future changes in command scheduling.

The dossier also identifies an existing fail-tolerant Get Connection Information test that reports an unexpected status while still passing. That is worth fixing separately because it reduces the reliability of the suite's aggregate pass count.

Neither issue undermines the kernel patch itself.

## **8. Additional tests I consider necessary**

These are the highest-value missing scenarios, in priority order.

| Priority | Target | Test                                                                                              |
| -------- | ------ | ------------------------------------------------------------------------------------------------- |
| P0       | B      | USB command completes, HCI response disappears, runtime suspend occurs before timeout             |
| P0       | D      | Successful system reset-resume on Realtek and an existing reset-resume-quirked device             |
| P0       | D      | Controller loses HCI state on reset; verify no old HCI traffic is exposed before reinitialization |
| P1       | B      | Force PM state to change between the status check and PM reference acquisition                    |
| P1       | D      | `btusb_resume()` fails; queued reset and disconnect compete                                       |
| P1       | D      | Multiple USB interfaces resume in different orders                                                |
| P1       | E      | Concurrent TX, suspend, resume and disconnect under SMP/lockdep                                   |
| P2       | A      | System sleep transition returns `-EACCES`; verify expected logging                                |
| P2       | CO-44  | Third-party-client semantics and additional timeout-producing MGMT operations                     |

The present QEMU/usbip results are strong evidence for the specific exercised paths. KASAN and lockdep add useful confidence, but they cannot validate a system-resume path that was never executed.

I would also keep one explicit distinction in the final review dossier: the first reset in the actual laptop incident is strongly explained by USB core's reset-resume path, but that specific attribution was inferred from the observed timing and source behavior, not directly recorded with USB-core dynamic debugging on the laptop.

## **9. Recommended submission structure**

I would reorganize the work into three separate upstream discussions.

**First: independent, low-risk fixes**

CO-43 A (failed-resume logging), CO-43 E (deferred-URB race), and CO-44 (MGMT timeout) can be reviewed separately. Pair CO-44 with its BlueZ test through separate kernel and BlueZ submissions.

**Second: coordinated resume recovery**

Keep B and D together for further investigation. Resolve B's incorrect general assumption about deferred commands and D's system-resume and reinitialization issues before proposing a final implementation.

A focused USB-core discussion about rebinding after successful runtime reset-resume would be valuable.

**Third: hardware-specific RFC**

Keep C independent, clearly marked as a proposed workaround, and supported by the existing hardware evidence. Do not make it a prerequisite for the general btusb fixes.

## **Final verdict**

The review changes my confidence differently for different components.

**Highest confidence:** E fixes a real synchronization window; CO-44 corrects a demonstrably incorrect status; A improves useful diagnostics.

**Conditional confidence:** B addresses a real workqueue stall but makes a broader assumption about unsent commands than the code guarantees.

**Insufficient confidence for upstream:** D addresses a genuine recovery problem but uses a mechanism that changes normal system-resume behavior and temporarily exposes potentially stale HCI state.

**Hardware hypothesis only:** C may be an effective mitigation, but its mechanism is not established by the single incident.

One limitation of my review: I independently inspected the current upstream btusb implementation and the historical commit introducing the MGMT mapping, and checked the provided pinned-source excerpts and diffs. I did not independently compile the proposed series or rerun the emulator. The reported test outcomes are therefore reviewed evidence, not tests I personally reproduced.

My highest-priority recommendation to the maintainer is **to implement the missing B1 scenario before changing anything else in B or D**. It tests a fundamental assumption on which the reset-suppression design depends. After that, I would investigate whether the BT-18 recovery can be implemented without a redundant USB reset.

Nothing has been submitted or changed in the repository as part of this review.
