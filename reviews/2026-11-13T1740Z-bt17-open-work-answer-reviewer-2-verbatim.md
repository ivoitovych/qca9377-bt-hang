# BT-17 open work — outside reviewer 2's answer to the task document

*Received 2026-11-13 in answer to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`. The
text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-13T1750Z-bt17-open-work-answers-checks.md`.*

---

# **BT-17 open work — independent technical review and research**

**Review target:** [2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/reviews/2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md)\
**Kernel baseline:** `bluetooth-next`, `da3cc02587c6`\
**Review scope:** T1–T7, including recovery design, USB-core behavior, deferred-URB lifetime, historical precedents, and regression testing.

## **Executive assessment**

The new document represents a substantial improvement over the intermediate review. Most importantly, it now contains an actual counterexample demonstrating that **CO-43 patch B can prevent recovery of a controller that the unpatched kernel successfully recovers**.

I also independently confirmed a second problem that deserves high priority: **the deferred-URB cleanup paths appear to leak both SKBs and USB control-request allocations**. This extends beyond the newly registered BT-24 race.

| Issue              | Assessment                                                             | Priority                   |
| ------------------ | ---------------------------------------------------------------------- | -------------------------- |
| T1 / BT-19         | B is demonstrably incorrect; recovery needs redesign                   | Blocker                    |
| T2 / BT-18         | Genuine USB runtime reset-resume recovery defect                       | Blocker                    |
| T3 / BT-24         | Failed-resume race plus independently confirmed ownership leaks        | Blocker for a combined fix |
| T4 / HCI Reset     | Recovery gap is real; intent requires further historical investigation | Should-fix                 |
| T5 / Prior art     | Relevant historical USB interface-rebinding precedent found            | Research finding           |
| T6 / Patch wording | A, E, CO-44 need precise, limited amendments                           | Minor                      |
| T7 / Emulator      | Strong fault-injection framework; more edge-case coverage required     | Should-fix                 |

The main architectural recommendation is to **separate command-timeout handling from potentially blocking USB recovery**, rather than decide whether the controller needs resetting solely from the current runtime-PM state.

There is also a potentially broader fix in the USB core. BT-18 should be investigated there before accepting a btusb-specific workaround that changes reset-resume behavior for multiple controller families.

## **Finding 1 — The deferred-URB ownership leak is real**

T3 · BLOCKER · Source-confirmed

Relevant baseline locations:

- `drivers/bluetooth/btusb_main.c:2198–2242` — `btusb_close()`
- `drivers/bluetooth/btusb_main.c:4989–5017` — `play_deferred()`
- `drivers/bluetooth/btusb_main.c:5019–5082` — `btusb_resume()`
- `drivers/usb/core/urb.c:118` and `:989` — anchor ownership and scuttling

The ownership chain is:

1. `alloc_ctrl_urb()` allocates a USB control-request structure.
2. It places the SKB in `urb->context`.
3. `submit_or_queue_tx_urb()` anchors the URB on `data->deferred`.
4. The caller releases its URB reference.
5. The anchor now keeps the URB alive.

A successful submission eventually invokes `btusb_tx_complete()`, which releases the SKB and setup packet.

However, `usb_scuttle_anchored_urbs()` only removes URBs from the anchor and drops the anchor references. It does not invoke the completion callback and does not know how to destroy the objects stored in `urb->context` or `urb->setup_packet`.

Therefore, both cleanup sites have an ownership problem:

- `btusb_close()` calls `usb_scuttle_anchored_urbs(&data->deferred)`.
- `btusb_resume()` calls it on the `failed:` path.

In addition, `play_deferred()` explicitly frees `urb->setup_packet` when submission fails or when clearing the remaining deferred URBs, but **never frees**`urb->context` in those paths.

That means the suspected leak is not limited to the BT-24 race. There are at least three relevant abandonment paths, all needing consistent cleanup.

This conclusion follows directly from the source's reference ownership. The leak has not yet been measured with kmemleak.

## **Finding 2 — T1: how patch B should be redesigned**

BLOCKER · Source-confirmed and supported by the dossier's emulator runs

### **The proposed deferred-anchor test is not sufficient**

The task asks whether this can distinguish a command that never reached hardware:

```
!usb_anchor_empty(&data->deferred)
```

**No. It establishes only that at least one URB is deferred.**

It does not establish that the *particular timed-out HCI command* is deferred.

The anchor can contain ACL traffic and other HCI commands. Moreover:

- A command can already have completed its USB transfer while its HCI response is missing.
- The failed-resume cleanup paths can remove an unsent command.
- Before E and BT-24 are fixed, deferred-anchor membership is not consistently synchronized with `txlock`.
- The command-timer callback does not pass btusb an identifier for the precise URB whose HCI completion is missing.

Conversely, a command's absence from `deferred` does not necessarily prove that the controller processed it.

If a precise distinction is required, it needs per-command transmission state, not aggregate anchor occupancy.

### **Can a command be in flight while autosuspend occurs?**

Ordinarily, btusb prevents that using `tx_in_flight`.

It increments the counter before submitting a TX URB, and `btusb_suspend()` refuses runtime autosuspend if the counter is nonzero.

But the counter is decremented when the **USB transfer** finishes. It is not held until the **Bluetooth HCI command** finishes.

This is precisely why the new `dropcmd-wedge` reproduction matters.

The recorded results are:

| Test              | USB transfer | HCI response | Reset      | Bluetooth afterward |
| ----------------- | ------------ | ------------ | ---------- | ------------------- |
| Unpatched, 3/3    | Completed    | Missing      | Performed  | Recovered           |
| A+B, 3/3          | Completed    | Missing      | Suppressed | Dead                |
| Final series, 3/3 | Completed    | Missing      | Suppressed | Dead                |

The failure persists even after the longer settling test. This is sufficient to reject B as written.

### **My preferred replacement: asynchronous, serialized recovery**

I would not use `pm_runtime_get_if_active()` as the primary solution. It avoids a blocking PM acquisition in some states, but it cannot distinguish a controller whose response was lost from one whose resume is still pending. It also does not itself solve the need to recover a suspended controller.

Likewise, `usb_autopm_get_interface_async()` is not a complete replacement. It requests runtime PM asynchronously; it does not establish that the USB device is ready for a reset before the deferred reset worker runs.

The appropriate design is to move the potentially blocking operation outside `hdev->workqueue` and serialize recovery.

Proposed recovery state machine

**HCI command times out**

`hci_cmd_timeout()` on ordered HCI workqueue

**Register recovery request and return immediately**

De-duplicate, hold lifetime reference, restrict new commands

**Independent recovery worker**

Wait for runtime-PM resolution without blocking HCI workqueue

Already reset and rebound

Discard stale recovery request

Same binding still unresponsive

Perform one coordinated USB reset

At a conceptual level, the change to `btusb_reset()` would be:

```
 static void btusb_reset(struct hci_dev *hdev)
 {
     struct btusb_data *data = hci_get_drvdata(hdev);
-    int err;
-
-    err = usb_autopm_get_interface(data->intf);
-    if (err) {
-        bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
-        return;
-    }
-
-    if (test_and_set_bit(BTUSB_RESET, &data->flags))
-        usb_autopm_put_interface_no_suspend(data->intf);
-
-    bt_dev_err(hdev, "Resetting usb device.");
-    usb_queue_reset_device(data->intf);
+    btusb_request_async_recovery(data);
 }
```

Here `btusb_request_async_recovery()` is a **proposed new facility, not an existing function**. This is an architectural sketch, not a buildable patch.

Its implementation must satisfy several additional invariants:

1. The request must remain alive through concurrent disconnect and rebind.
2. It must not dereference freed `btusb_data`.
3. Recovery must be coalesced: one request per unresolved failure, not one reset per timed-out command.
4. A successful USB-core reset-resume and rebind must invalidate stale recovery requests.
5. The USB device must be held active until any requested reset actually runs.
6. New HCI commands must not run through an unrecovered transport and trigger another timeout cascade.

An important warning: simply moving the existing `usb_autopm_get_interface()` into `reset_work` and adding `cancel_work_sync()` in `btusb_disconnect()` is **not necessarily safe**. If the recovery worker is waiting for a PM transition whose completion initiates disconnect/rebind, synchronous cancellation can create a circular wait.

A detached, reference-counted recovery request, or an equivalent proven lifetime mechanism, is necessary.

I am not confident a minimal btusb-only diff can meet all four T1 requirements without also resolving BT-18 and the recovery lifetime rules. I would not offer a seemingly complete twenty-line patch that silently introduces these problems.

### **What about command credits?**

`hci_cmd_timeout()` currently restores credit after `hdev->reset()` returns.

An asynchronous callback changes that ordering. If recovery is merely queued, the HCI worker can start issuing more commands while the USB device is still failing.

This is not desirable.

I recommend treating recovery as an explicit state in which new HCI transmissions are rejected or held until recovery completes. Existing synchronous requests should receive an appropriate error rather than waiting through repeated two-second timeouts.

For BT-17, three timeout messages instead of one may be tolerable as an interim diagnostic artifact. I would not make that normal behavior in a final upstream fix.

## **Finding 3 — T2: BT-18 belongs in a USB-core discussion first**

BLOCKER · Source-confirmed

The relevant source path is:

```
drivers/usb/core/hub.c
  finish_port_resume()
    -> normal resume fails
    -> persist allows reset-resume
    -> USB reset succeeds

drivers/usb/core/driver.c
  usb_resume_both()
    -> usb_resume_interface()
       -> no driver->reset_resume
       -> intf->needs_binding = 1

  usb_runtime_resume()
    -> returns without rebinding interfaces
```

By contrast, the system-resume path uses `usb_resume_complete()` to rebind the marked interfaces.

### **Important historical precedent**

I independently found and checked upstream commit:

[6aec044cc2f5 — USB: unbind all interfaces before rebinding any](https://github.com/torvalds/linux/commit/6aec044cc2f5670cf3b143c151c8be846499bd15) (12 March 2014, Alan Stern).

This is directly relevant to BT-18.

It established that drivers which claim more than one USB interface must have **all affected interfaces unbound before any are rebound**. Otherwise the new binding can fail while another interface remains claimed by the old driver.

The rationale and its inclusion in stable review are independently documented.

This matters because btusb commonly has multiple interfaces.

A naive solution that schedules one independent rebind operation per interface could violate the ordering that the 2014 fix deliberately established.

### **What I recommend for the USB core**

The USB-core solution should operate at the **USB-device level**, not independently per interface.

It should identify a successful runtime reset-resume that marked one or more interfaces as needing rebinding, then arrange a coordinated unbind/rebind after the runtime-PM transition reaches a safe point.

It must preserve the multi-interface ordering, device locking, PM usage references, and existing system-resume behavior.

The call should not simply be inserted inside `usb_resume_interface()`. That function does not own the locks needed for driver unbinding.

Nor would I deliberately fail an otherwise successful USB resume merely to force recovery. The USB device itself may be healthy, as the BT-18 emulator demonstrates.

**Is the asymmetry intentional?** I cannot establish that from the historical record. The `USB_QUIRK_RESET_RESUME` autosuspend gate clearly prevents some predictable reset-resumes when a driver lacks the callback. But the USB persist recovery path can encounter reset-resume after an unexpected ordinary resume failure. It is not prevented by that gate.

That appears to be an overlooked recovery case, and it is worth asking the USB maintainers before proposing implementation code.

### **Draft question for linux-usb**



Hi,

I found a case where a successful runtime reset-resume leaves a USB interface driver bound but unusable.

On bluetooth-next da3cc02587c6, a btusb device is runtime-suspended. Its next host-initiated resume fails the device-status request. With USB persist enabled, the core successfully performs a reset-resume.

btusb has no reset_resume callback, so usb_resume_interface() sets intf->needs_binding. However, usb_runtime_resume() returns after usb_resume_both(), without rebinding the marked interfaces. The system-resume path handles this through usb_resume_complete(), and usb_reset_device() also handles marked interfaces.

In a QEMU/usbip reproduction using an emulated 13d3:3503 controller, the device answers USB requests after the reset, but btusb never resumes, BTUSB_SUSPENDING remains set, and a subsequent HCI power-on times out. The unpatched close/recover scenario reproduced this in 5/5 runs.

Is the absence of interface rebinding after runtime reset-resume intentional?

If this is an unintended gap, would the appropriate fix be a device-level deferred unbind/rebind after runtime resume has completed? In particular, commit 6aec044cc2f5 documents the need to unbind all affected interfaces before rebinding any when drivers claim multiple interfaces.

I would appreciate guidance on the correct PM and device-locking context for this recovery.

Thanks,\
Iaroslav Voitovych

This is a draft only; nothing has been sent.

## **Finding 4 — T3: proposed BT-24 and leak correction**

The following is a minimal **implementation sketch against**`da3cc0258`. It shows how I would couple the failed-resume race correction with cleanup of abandoned URBs.

First, introduce one helper before `btusb_close()`:

```

static void btusb_discard_deferred(struct btusb_data *data)
{
    struct urb *urb;

    /* Caller holds data->txlock. */
    while ((urb = usb_get_from_anchor(&data->deferred))) {
        dev_kfree_skb_any(urb->context);
        kfree(urb->setup_packet);
        usb_free_urb(urb);
    }
}

```

The helper uses `usb_get_from_anchor()` to obtain an owned reference before freeing each unsubmitted URB.

`dev_kfree_skb_any()` is appropriate because the helper can execute with interrupts disabled.

Next, replace the failed-resume cleanup:

```

@@ btusb_resume()
 failed:
-    usb_scuttle_anchored_urbs(&data->deferred);
+    spin_lock_irq(&data->txlock);
+    btusb_discard_deferred(data);
+    clear_bit(BTUSB_SUSPENDING, &data->flags);
+    spin_unlock_irq(&data->txlock);
+    return err;
+
 done:
     spin_lock_irq(&data->txlock);
     clear_bit(BTUSB_SUSPENDING, &data->flags);
     spin_unlock_irq(&data->txlock);

```

This makes the cleanup and the transition out of `BTUSB_SUSPENDING` atomic with respect to TX decisions protected by `txlock`.

I prefer this ordering to simply clearing `BTUSB_SUSPENDING` before scuttling. Clearing first would allow new URBs to bypass the deferred queue while the RX transport has already failed to restart.

The same helper should replace the scuttle in `btusb_close()`, under `txlock`:

```

@@ btusb_close()
     struct btusb_data *data = hci_get_drvdata(hdev);
+    unsigned long flags;
     int err;

@@
 failed:
-    usb_scuttle_anchored_urbs(&data->deferred);
+    spin_lock_irqsave(&data->txlock, flags);
+    btusb_discard_deferred(data);
+    spin_unlock_irqrestore(&data->txlock, flags);
     return 0;

```

Finally, correct the missing SKB cleanup inside `play_deferred()` itself:

```

@@ play_deferred()
         err = usb_submit_urb(urb, GFP_ATOMIC);
         if (err < 0) {
             if (err != -EPERM && err != -ENODEV)
                 BT_ERR("%s urb %p submission failed (%d)",
                        data->hdev->name, urb, -err);
+            dev_kfree_skb_any(urb->context);
             kfree(urb->setup_packet);
             usb_unanchor_urb(urb);
             usb_free_urb(urb);
             break;
         }

@@
     while ((urb = usb_get_from_anchor(&data->deferred))) {
+        dev_kfree_skb_any(urb->context);
         kfree(urb->setup_packet);
         usb_free_urb(urb);
     }

```

### **Qualifications before using this implementation**

This sketch is intentionally limited to URBs that were never successfully submitted.

It needs validation against the actual URB ownership rules, concurrency with `btusb_close()`, and the HCI shutdown path. Holding `txlock` while freeing an arbitrarily large deferred queue is also not ideal; a production implementation could detach the queue under the lock and free its contents afterward.

There is another semantic issue beyond memory ownership: **a dropped HCI command should not necessarily be left to fail only when its synchronous request timer expires**.

For a failed resume, the Bluetooth command layer should be notified of transport failure. Calling `hci_cmd_sync_cancel()` under `txlock` is not advisable without proving its locking behavior. I would first collect whether any command SKBs were discarded, release `txlock`, and then notify the HCI layer once through its appropriate error path.

The current `failed:` behavior clears `BTUSB_SUSPENDING` even if the receive transport is unavailable. The sketch preserves that existing behavior; it does not solve recovery from a permanently failed interrupt/bulk resubmission. That requires a separate decision.

I recommend registering the ownership issue independently from BT-24's synchronization issue, even if a single combined cleanup patch ultimately fixes both.

## **Finding 5 — T4: HCI Reset can fail without triggering USB recovery**

SHOULD-FIX · Source-confirmed; intent not fully established

The source behavior is unambiguous.

In `net/bluetooth/hci_core.c:4331–4357`, `hci_cmd_work()` handles an HCI Reset differently from ordinary commands:

```
if (test_bit(HCI_RESET, &hdev->flags) ||
    hci_dev_test_flag(hdev, HCI_CMD_DRAIN_WORKQUEUE))
    cancel_delayed_work(&hdev->cmd_timer);
else
    queue_delayed_work(hdev->workqueue, &hdev->cmd_timer,
                       HCI_CMD_TIMEOUT);
```

Meanwhile, `hci_reset_sync()` sets `HCI_RESET` and waits for the Reset command through the synchronous-command mechanism.

If that wait expires, `__hci_cmd_sync_sk()` returns `-ETIMEDOUT`.

The important consequence is that **the normal**`hci_cmd_timeout()`**callback, which invokes**`hdev->reset()`**, is not scheduled for that Reset command**.

This explains the new emulator observation: a controller can remain unresponsive across power-on attempts without another USB-level recovery being triggered.

### **Is this intentional?**

The timer suppression appears deliberate, and there is a plausible reason.

The synchronous HCI initialization/reset operation already has its own timeout handling. Running the generic HCI command-timeout recovery simultaneously could produce duplicate resets, reentrancy, or competing controller initialization.

Older HCI-core code also explicitly documents avoiding recovery-event injection during initialization because initialization has its own timeout procedure.

That supports the interpretation, but I did not find a definitive upstream discussion explaining the exact `HCI_RESET` timer condition.

I therefore would **not** remove the condition as a quick fix.

### **Recommended approach**

Handle the failed initialization/reset operation at a higher level:

- Detect that the synchronous HCI Reset failed because the controller did not respond.
- Request one device-level recovery, if the transport supports it.
- Perform recovery outside the ordered HCI workqueue.
- Bound the number of retries and prevent recursive initialization/reset loops.
- Preserve ordinary behavior for controllers that return an explicit HCI Reset error rather than timing out.

A good regression test is exactly the existing `dropcmd-wedge` scenario, extended so that the first power-on HCI Reset fails and the recovery policy must make the device usable again.

I would treat T4 as a separate issue from BT-19. It shares the same eventual recovery machinery but has a different trigger and different state constraints.

## **Finding 6 — T5: independently established prior art**

The following commits are especially relevant.

| Source                                                                                                                          | What it establishes                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| [6aec044cc2f5](https://github.com/torvalds/linux/commit/6aec044cc2f5670cf3b143c151c8be846499bd15) (2014) | All affected interfaces must be unbound before rebinding, especially for multi-interface drivers                    |
| [7bee549e197c](https://github.com/torvalds/linux/commit/7bee549e197c) (2009)                             | Introduced btusb autosuspend, deferred URBs, the wake worker, and TX-in-flight accounting                           |
| [161510ccf91c](https://github.com/torvalds/linux/commit/161510ccf91c) (2021)                             | Introduced the incorrect MGMT `-ETIMEDOUT` conversion                                                               |
| [dcaf83ead130](https://github.com/torvalds/linux/commit/dcaf83ead130) (2026)                             | Describes a hardware-specific Ryzen/MediaTek remote-wakeup failure and the decision to refuse some runtime suspends |

A few conclusions follow from these histories.

**For E:** `7bee549e197c` is an appropriate `Fixes:` reference. Its original description specifically discusses the relationship between deferred URBs and autosuspend/TX synchronization.

**For BT-18:** `6aec044cc2f5` means that a USB-core correction must preserve coordination among interfaces. It is particularly relevant to a driver claiming both a primary Bluetooth interface and additional interfaces.

**For C:** `dcaf83ead130` supports considering a targeted quirk, but it documents a different device family and a specifically reported remote-wakeup mechanism. It is precedent for a mitigation strategy, not proof of a shared root cause.

**For CO-44:** the original `161510ccf91c` change supplies no explanation for why a command timeout should be considered an authentication failure. The current protocol definitions make a clear distinction: authentication failure is `0x05`; operation timeout is `0x08`.

### **Findings not established by the external search**

I searched for indexed linux-usb discussions about runtime reset-resume rebinding, discussions and patches touching `mgmt_errno_status()` and the affected btusb paths, and reports of authentication errors for non-authentication MGMT operations.

I did not identify a specific public review thread that explains the 2021 `-ETIMEDOUT` choice, a later accepted correction to it, or a directly matching upstream patch addressing BT-18's runtime-resume rebinding gap.

I also found no verified example of an external MGMT client explicitly depending on `AUTH_FAILED` as the response to an ordinary command timeout. That is not proof such a client does not exist.

The source search is useful but not exhaustive across every mailing-list archive, vendor kernel and out-of-tree Bluetooth application.

## **Finding 7 — T6: proposed final patch wording**

These are the commit messages I would use after the corresponding implementation and testing decisions are complete.

### **A — Failed-resume logging**

Bluetooth: btusb: Report failed runtime PM wakeups for deferred TX

When btusb defers a TX URB while suspended, btusb_waker() takes a runtime PM reference to resume the device.

If usb_autopm_get_interface() fails, the worker returns silently. An HCI command waiting on the deferred anchor may then time out. Other code paths can report the PM error later, but the failed wake attempt itself is not logged.

Log unexpected failures of the wake attempt. Exclude -EACCES, which can occur when runtime PM is disabled, including during system sleep transitions.

This removes the claims that the resume failure was never otherwise logged and that `-EACCES` means exclusively system sleep.

### **E — Successful-resume race**

Bluetooth: btusb: Anchor deferred TX URBs under txlock

submit_or_queue_tx_urb() checks BTUSB_SUSPENDING under txlock but anchors a deferred URB after releasing the lock.

A concurrent btusb_resume() can drain the deferred anchor and clear BTUSB_SUSPENDING between those operations. The sender then anchors its URB after the drain has completed, leaving it unsent until a later resume. An HCI command carried by that URB can time out.

Anchor the URB in the same critical section as the suspend-state check. btusb_resume() already drains the deferred anchor while holding txlock, so the decision and the drain are now ordered.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")

This deliberately limits E to the successful-resume race. It makes no claim about the separate failed-resume cleanup race in BT-24.

### **CO-44 — MGMT timeout status**

Bluetooth: MGMT: Report command timeouts as MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED, even when a controller simply fails to answer an HCI command.

For example, when Write Class of Device times out during a Set Device Class or UUID update, the MGMT command reports Authentication Failed although no authentication was attempted.

MGMT_STATUS_TIMEOUT already exists. The HCI-status conversion table also uses it for controller timeout statuses.

Map -ETIMEDOUT to MGMT_STATUS_TIMEOUT instead.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")

---

This changes the MGMT completion status for commands returning -ETIMEDOUT from Authentication Failed (0x05) to Timeout (0x08). The errno conversion thereby agrees with the existing HCI-status mappings for connection and host timeouts.

The original -ETIMEDOUT mapping was introduced by the referenced commit without an explanation of the choice.

**Stable recommendation:** I would initially submit without `Cc: stable`, while retaining the `Fixes:` tag. The correction is small and a good eventual backport candidate, but it changes a userspace-visible protocol status. I would first seek upstream agreement on that compatibility implication.

I agree with the new dossier that adding a generic `-EACCES → MGMT_STATUS_AUTH_FAILED` mapping would be incorrect. HCI Authentication Failure (`0x05`) and Pairing Not Allowed (`0x18`) both become `EACCES`, while their MGMT statuses differ.

### **C — Only if a hardware-specific RFC is eventually justified**

Bluetooth: btusb: Avoid QCA9377 runtime suspend with wakeup armed on Ryzen

An IMC Networks QCA9377 (13d3:3503) on a Ryzen laptop became unresponsive after an extended idle runtime suspend. The following HCI command timed out, USB reset attempts failed, and recovery required a power cycle.

The kernel logs show that btusb suspended the device but did not complete a corresponding resume before the disconnect. A failed post-resume device-status request is consistent with the timing and USB-core behavior, and was reproduced using an emulated controller. That request was not directly captured on the laptop.

As a possible mitigation, apply BTUSB_WAKEUP_BROKEN to this device when attached directly to a Ryzen root hub. This prevents runtime autosuspend while the HCI device requires remote wakeup, without disabling system sleep.

The underlying firmware or platform failure mechanism has not been established.

I would keep this RFC local until stronger hardware evidence exists.

## **Finding 8 — T7: emulator assessment and missing experiments**

SHOULD-FIX · Harness source reviewed

The emulator has become a useful regression-testing tool. It exercises the real btusb driver, the USB runtime-PM path, kernel MGMT, and controller-facing behavior under QEMU rather than merely unit-testing isolated helper functions.

The revised harness now checks functional outcomes, propagates failure exits and supports a controller that completes a USB command transfer but never emits the HCI completion. Those changes address major limitations from the earlier review.

However, the new open work identifies scenarios that are not yet validated.

### **The reset-detection heuristic**

The `--wedge-until-reset` mode currently treats a `SET_CONFIGURATION` control request as evidence of a USB reset.

That is a useful proxy, because USB reset/reconfiguration procedures can send `SET_CONFIGURATION`.

It is not an unambiguous reset signal.

A configuration request can occur for another reason, while a reset that fails before configuration restoration might never generate that request.

I would record two distinct observations:

- **Emulator:** `SET_CONFIGURATION` received after the controller was wedged.
- **Kernel:** a USB reset actually initiated and completed, or failed.

Correlating the two through USB-core tracepoints or dynamic-debug output would give stronger evidence than inferring the reset solely from the USB control request.

The current test still proves that the implemented fault model becomes healthy after the selected trigger. It just should not claim that the trigger independently proves a completed hardware reset.

### **Four additional emulator modes**

**Mode 1 — Lost queued reset**

Delay `__usb_queue_reset_device()` long enough for runtime autosuspend to occur. Confirm that `usb_lock_device_for_reset()` can return `-EHOSTUNREACH`, then test whether the proposed recovery implementation preserves the PM reference until reset completion.

The injection should be debug-only and deterministic.

**Mode 2 — QCA firmware state lost after reset**

After the simulated reset, make `QCA_CHECK_STATUS` report that patch and NVM are not loaded. Require the newly probed driver to perform setup before any ordinary HCI traffic succeeds.

The emulator will need to implement the relevant vendor download requests and validate the expected sequence. Merely returning a different status is insufficient if the subsequent firmware protocol is not modeled.

**Mode 3 — BT-24 failed-resume race**

Inject a one-shot immediate failure from `btusb_submit_intr_urb()` or `btusb_submit_bulk_urb()` during resume, such as `-ENOMEM`.

A negative return from `usb_submit_urb()` is required to exercise `btusb_resume()`'s `failed:` branch. Simply having the USB emulator complete an already-submitted RX URB with an error will generally take a different path.

Concurrently submit a class-write request and widen the cleanup window with a debug-only delay. Verify that no deferred URB survives the failure transition.

**Mode 4 — Deferred-URB memory ownership**

Enable `CONFIG_DEBUG_KMEMLEAK` and repeat abandoned command-URB scenarios across close and failed-resume paths.

Examine leaks of `struct usb_ctrlrequest` allocations and SKBs. Repeat after the cleanup changes and compare results.

KASAN and lockdep passing does not establish that these allocations are freed.

### **Testing system suspend without the laptop**

I see a feasible direction that avoids relying on the userspace Raw Gadget process during system suspend.

Use `dummy_hcd` with an **in-kernel USB gadget function** that implements the minimal Bluetooth interface, QCA vendor requests and HCI behavior needed for the test.

Unlike a userspace emulator, the kernel gadget code is not stopped by the userspace freezer.

This could provide a way to test USB reset-resume and system-resume semantics with `pm_test=devices`, while preserving deterministic fault injection.

The cost is a considerably more involved emulator implementation.

A smaller first experiment would be a generic in-kernel gadget and a minimal test USB interface driver, to validate the USB-core rebinding semantics independently of btusb. A full btusb/QCA emulator could follow.

Real hardware would still be needed to validate physical xHCI behavior, controller firmware retention, and genuine wakeup signaling.

## **Final recommended work order**

I would now adjust the project's plan as follows.

1. **Prepare A, E and CO-44 independently.** They have the strongest evidence and the smallest implementation changes. E should receive its final stress test; the BlueZ test should follow the kernel MGMT correction.
2. **Investigate BT-24 and the deferred-URB leaks immediately.** This is an independent correctness and resource-lifetime issue that should not have to wait for the USB-core discussion.
3. **Ask linux-usb about BT-18**, explicitly including the multi-interface ordering established by `6aec044cc2f5`. Do not replace D with another untested reset-resume callback yet.
4. **Design B and T4 around one asynchronous recovery mechanism.** Make the state machine and object lifetime explicit before implementation. Preserve recovery for an already-transmitted command that receives no HCI response.
5. **Extend the emulator with negative and teardown cases.** In particular, make failed reset scheduling, failed RX resubmission, reset-induced firmware loss and memory ownership independently observable.
6. **Keep C separate as a hardware hypothesis.** It should not complicate the correctness fixes for btusb and the USB core.

My assessment is that **BT-24 and the deferred-URB ownership problem are the most immediately actionable new findings**, while BT-18 and BT-19 need more substantial design work.

The investigation has also reached an important point: the evidence is now strong enough to support separate, narrowly scoped upstream fixes without requiring the project to solve the original QCA9377 hardware hang first.

**Review limitations:** I checked the supplied pinned source, patch diffs, emulator source and logs, plus independent upstream history and kernel documentation. I did not run a kernel build, kmemleak, or new fault-injection experiment during this review. The proposed cleanup code remains a review sketch pending compilation and runtime validation. Nothing was modified or sent.
