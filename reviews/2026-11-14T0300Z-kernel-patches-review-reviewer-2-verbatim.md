# Kernel patches ready to send — outside reviewer 2's answer

*Received 2026-11-14 in answer to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes, and one remark outside the patches (reviewer 6), marked
where it stood. What we checked, point by point, is in
`2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.*

---

# **Kernel patch submission review — 14 November 2026**

**Reviewed dossier:** [Kernel patches ready to send — outside review](https://github.com/ivoitovych/qca9377-bt-hang/blob/main/reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md)

**Baseline:** `bluetooth-next` at `da3cc02587c629420603df4395179ec82955c941`, with separate stable-tree targets.

The dossier covers 12 items: standalone Bluetooth fixes, mesh-management corrections, SCO fixes, stable backports, and the still-experimental BT-17 recovery series. It includes patch text, test results, and local CI evidence.

## **Initial submission decision**

**I would not send all 11 packages marked ready as one batch without changes.** Some have persuasive tests and limited scope, while others contain dependency or integration questions that should be resolved first.

One concrete problem is already established:

**Item 4 — CO-38:** The one-line kernel correction is sensible and has a targeted passing regression test. However, the accompanying three-patch BlueZ test series introduces eight cases that still fail on the unmodified extended-advertising duration behavior addressed by the separate CO-12 work.

Those failures are acknowledged in the dossier. Sending all three tests as an immediately mergeable series would introduce known failures into BlueZ's normal test suite. The independent instance-listing regression test should be separated from the duration tests unless CO-12 is accepted as a coordinated dependency.

This is a **test-series submission blocker**, not an objection to CO-38's kernel fix.

## **Per-item verdict**

| #  | Contribution                                 | Review disposition                                            |
| -- | -------------------------------------------- | ------------------------------------------------------------- |
| 1  | CO-44 — MGMT timeout status                  | Ready after minor editorial correction                        |
| 2  | CO-43 E — deferred-URB locking               | Ready; stable consideration optional                          |
| 3  | CO-43 A — failed-resume logging              | Ready after small wording adjustment                          |
| 4  | CO-38 — advertising instance listing         | Kernel fix ready; split BlueZ tests                           |
| 5  | CO-04 — mesh use-after-free                  | Promising; needs stronger concurrency verification            |
| 6  | CO-05 + CO-26 — mesh list and error handling | Good direction; review jointly with CO-04                     |
| 7  | CO-35 — L2CAP ECRED stable backports         | Reasonable stable requests; validate prerequisites            |
| 8  | CO-22 — ASUS ROME stable IDs                 | Reasonable request                                            |
| 9  | CO-21 — SCO alternate-setting selection      | Further synchronization and mixed-mode review                 |
| 10 | CO-20 — SCO receive diagnostics              | Patch 1 reasonable; patch 2 needs a classification correction |
| 11 | CO-43 remaining BT-17 recovery               | **Do not submit yet**                                         |
| 12 | CO-02 v2 — SCO connection reuse              | Promising; strengthen cancellation and parameter tests        |

These dispositions assess the code and evidence in this dossier, not the eventual response of upstream maintainers.

### **1. CO-44 — MGMT reports timeout as authentication failure**

**Verdict: ready, minor corrections.**

The one-line change in `net/bluetooth/mgmt.c:299` is justified:

```
 case -ETIMEDOUT:
-    return MGMT_STATUS_AUTH_FAILED;
+    return MGMT_STATUS_TIMEOUT;
```

The new test distinguishes the two kernels, and the mapping agrees with the existing timeout entries in `mgmt_status_table[]`.

The introduction at dossier lines 72–74 contains a factual mistake:

> `mgmt_errno_status()` has no case for it

The function explicitly **does have** a `-ETIMEDOUT` case; the case returns the wrong MGMT status. Correct that sentence.

The commit message's technical explanation is materially better than the previous version. I would retain the one-line scope and not add an `-EACCES` conversion. Both HCI Authentication Failure and Pairing Not Allowed can become `EACCES`, but they have different MGMT meanings.

I see no need to make `Cc: stable` a prerequisite. A `Fixes:` tag allows the stable maintainers to identify it, while the status change is visible to userspace. The `Link:` to the 2022 posting is optional; it is useful only if that posting describes this exact incorrect-status behavior. Otherwise, the captured incident and regression test are stronger evidence.

For the BlueZ test, ensure the hook actually observed the Write Class of Device opcode before accepting the expected timeout as a successful test.

### **2. CO-43 E — Anchor deferred URB under**`txlock`

**Verdict: ready, subject to the final locking audit.**

The change at `drivers/bluetooth/btusb_main.c:2388` is small and correctly targets the successful-resume race.

```
spin_lock_irqsave(&data->txlock, flags);
suspending = test_bit(BTUSB_SUSPENDING, &data->flags);

if (!suspending)
    data->tx_in_flight++;
else
    usb_anchor_urb(urb, &data->deferred);

spin_unlock_irqrestore(&data->txlock, flags);
```

`usb_anchor_urb()` uses spinlock-compatible operations, and the existing resume path already takes the anchor lock while holding `txlock`. The patch does not introduce a new evident lock-order inversion.

The `Fixes: 7bee549e197c` tag matches the commit that introduced btusb autosuspend and deferred URBs.

The ten 100-cycle stress runs add useful confidence, even though they cannot establish the absence of every race.

I would send this independently of the other BT-17 fixes. I would omit `Cc: stable` initially unless maintainers consider the reproduced hang sufficiently likely in real use. Its age alone does not prove that it is common.

### **3. CO-43 A — Failed runtime-resume diagnostics**

**Verdict: ready with a small wording change.**

The code is minimal and has no obvious correctness or lifetime problem. Logging the result of the waker's failed `usb_autopm_get_interface()` is useful.

At dossier lines 851–857, the message implies that the subsequent timeout is the only explanation available. That should be softened, because other paths can log related USB PM errors.

I would also consider shortening the new error to:

```
bt_dev_err(data->hdev,
           "Failed to resume for deferred TX: %d", err);
```

The current message is not wrong, just longer than necessary.

No `Fixes:` or stable request is necessary for a diagnostics-only addition.

### **4. CO-38 — Read Advertising Features hides remaining instances**

**Verdict: kernel patch ready; BlueZ series should be split.**

The baseline code at `net/bluetooth/mgmt.c:8892` compares an instance identifier with a count:

```
- if (adv_instance->instance <= hdev->adv_instance_cnt) {
+ if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
```

That is a real defect: instance identifiers are not necessarily a contiguous sequence from 1 to the current number of instances.

The example of adding instances 1 and 2, then deleting 1, demonstrates the error cleanly. The allocation size remains based on the instance count, so this change does not obviously create a response-buffer overflow.

I independently confirmed `b338d91703fa` as the introduction of Mesh support, making it a reasonable `Fixes:` reference.

The regression evidence is persuasive: the new instance-listing case fails consistently before the fix and passes after it.

**Requested change:** extract `mgmt-tester: Add test for listing a remaining instance 2` into its own BlueZ submission. Do not make its acceptance depend on the larger 506-line duration-test patch or on the separate CO-12 work.

For the remaining duration tests, either coordinate their landing with CO-12 or arrange for their expectations to pass against the currently supported kernel behavior.

### **5. CO-04 — Use-after-free in**`mesh_send_sync()`

**Verdict: promising security/correctness fix, but I want another locking review before sending.**

The reported use-after-free is independently visible in [the syzbot report](https://syzbot.org/bug?extid=f20755f37da70df33a16). The queue-handoff race described in the patch is plausible and matches the reported read of the freed `mesh_tx` object.

I agree with the key design decision: keep `HCI_MESH_SENDING` set until the decision to start the next request or become idle has been made under `hdev->lock`.

I also agree that avoiding `hdev->lock` while holding `cmd_sync_work_lock` is essential, because the MGMT queueing path already establishes the opposite lock order.

The new `mesh_next()` loop is sensible in principle: if one queued start cannot be created, complete that failed entry and continue to the next rather than leave the queue stalled.

**My concern is the remaining**`-ECANCELED`**completion path.**

At dossier lines 2151–2160:

```
if (err == -ECANCELED) {
    mesh_send_complete(hdev, mesh_tx, false);
    return;
}
```

The comment explains why this path cannot simply acquire `hdev->lock`: the callback can be invoked while `cmd_sync_work_lock` is held.

But there are two distinct callers:

- `send_cancel()`, where the patch has already taken `hdev->lock`.
- `hci_cmd_sync_clear()`, where the same lock is not guaranteed by this callback.

In the second case, `mesh_send_complete()` removes and frees an entry without acquiring the lock protecting the pending-mesh list.

That behavior predates this patch, but it remains relevant to the completeness of the proposed synchronization fix.

I would investigate concurrent controller unregister and MGMT mesh operations, checking the exact locking and lifetime guarantees around `hci_cmd_sync_clear()`.

There is a related smaller issue: `mesh_send_done_sync()` still reads `list_empty(&hdev->adv_instances)` before acquiring `hdev->lock`. That list access deserves inclusion in the locking audit, even though it is not the direct cause of the reported UAF.

**Strongly recommended:** run the actual syzbot reproducer against the candidate. The dossier explicitly says that the original UAF was not reproduced, so clean KASAN runs demonstrate no observed regression, not verified elimination of the reported fault.

The lockdep comparison is useful: 2/35 baseline boots versus 0/35 patched boots, with a plausible removal of the callback path causing the inversion. I would mention the lock-order fix in the commit body, but I would not claim statistical proof from that sample alone.

A stable request is reasonable once the complete cancellation paths are verified. There is already independent upstream discussion of the same duplicate-queue mechanism, so a concise explanation of why this approach differs would also help maintainers.

### **6. CO-05 + CO-26 — Mesh advertising lock and failed add**

**Verdict: two justified changes, with a remaining broader race to acknowledge.**

Patch 1 protects the capacity check, advertising-instance insertion and list traversal with `hdev->lock`.

The measured lock-assertion result — three warnings per baseline boot and none with the patch — is good evidence that it fixes the unprotected `hci_add_adv_instance()` calls.

Patch 2 correctly preserves the error from a failed `hci_add_adv_instance()`, rather than scheduling an instance that was never inserted. This is a straightforward error-path correction.

The main limitation is already acknowledged in the cover letter: `hci_schedule_adv_instance_sync()` still looks up an advertising instance without equivalent lifetime protection.

This matters because a separate, broader upstream advertising-instance UAF series identified precisely such unlocked lookups. The Bluetooth maintainer discussed copying instance data under `hdev->lock` and releasing the lock before controller commands, rather than retaining pointers across unlocked HCI operations.

I would therefore word CO-05 narrowly: it fixes the *mesh insertion and capacity-check race*, not the lifetime of every advertising instance touched by mesh transmission.

**Series ordering:** CO-04 and CO-05 touch related execution and cancellation paths, so I would send them with a clear cross-reference. They can remain separate logical fixes, but the combined tree deserves a dedicated KASAN/lockdep test, especially on cancellation and controller removal.

For CO-26, I see no reason that the error-handling patch must depend on the larger synchronization redesign. If it applies and behaves correctly independently, it could be submitted alone as a small fix.

### **7. CO-35 — L2CAP ECRED deferred-accept stable backports**

**Verdict: reasonable stable submissions, with clear limits.**

I independently verified the two mainline commits:

- [608e0b7a675b](https://github.com/torvalds/linux/commit/608e0b7a675b) — introduces the required L2CAP locking helpers.
- [32d86e048d8e](https://github.com/torvalds/linux/commit/32d86e048d8e) — corrects the lock handling in deferred ECRED acceptance.

They are related by an implementation dependency: the second commit needs helpers introduced by the first.

The reported test is directly relevant. An unpatched deferred-accept case hangs consistently, and the patched test finishes in approximately one second on the tested stable lines.

The deviations on 6.18.y, 6.12.y and 6.6.y are explained, including removal of annotations unavailable in the older trees and context adjustments for `l2cap_sock_recvmsg()`.

The 7.3.y request appropriately asks for the original pair instead of a newly invented stable-only fix.

I would retain the separate request for `5874f8d03268`, the SCI response-layout correction. It is independently relevant to the 7.3.y tester and should not be represented as a dependency of the ECRED deadlock fix itself.

**One recommendation:** for each backport, include a compact table of semantic deviations from the two mainline commits, distinguishing actual code changes from dropped annotations and context differences. The dossier contains this information, but a stable maintainer should not have to reconstruct it from multiple cover letters.

The 6.1.y and older lines are explicitly outside the prepared backports, despite reproducing the hang with ECRED enabled. That limitation is acceptable; it should remain visible rather than suggesting the full affected population has been addressed.

### **8. CO-22 — ASUS QCA ROME device entries for stable**

**Verdict: no substantive objection.**

I independently verified the original commits:

[d54601f21faf](https://github.com/torvalds/linux/commit/d54601f21faf) and [cfa67a1dbfd9](https://github.com/torvalds/linux/commit/cfa67a1dbfd9).

They add the ASUS USB identifiers `0b05:1868` and `0b05:1825` to QCA ROME handling.

The justification is clear: generic Bluetooth-class matching does not arrange QCA firmware setup, whereas the device-specific quirk does.

It is also appropriate that the message distinguishes the original authors' reported hardware tests from the project's build and cherry-pick verification.

The seven tested stable lines cover a useful range. An unchanged warning/failure set on 6.6.y is not a regression attributable to these entries.

I would keep the stable request narrowly focused on these two already-merged commits. There is no need to include the unmerged Surface Laptop QCA ID patch in this request.

The remaining administrative step is to recheck whether either change has entered the stable queue immediately before sending, to avoid a duplicate request.

### **9. CO-21 — SCO alternate-setting selection**

**Verdict: useful design, but I would request one more revision before submission.**

The original bug is convincingly demonstrated: choosing an isochronous alternate setting from the last notification rather than the set of active links is not reliable when multiple SCO/eSCO links exist.

Recording the negotiated air mode on `struct hci_conn` is reasonable. The mode belongs to the individual connection, and the HCI Synchronous Connection Complete event is an authoritative source for it.

The main concern is the new helper at `include/net/bluetooth/hci_core.h`, around line 1153:

```
rcu_read_lock();

list_for_each_entry_rcu(c, &h->list, list) {
    if ((c->type == SCO_LINK || c->type == ESCO_LINK) &&
        c->state == BT_CONNECTED && !c->codec.data_path &&
        c->air_mode == air_mode)
        num++;
}

rcu_read_unlock();
```

RCU protects the lifetime of the traversed connection objects, but it does not automatically provide a consistent snapshot of their mutable fields.

`state`, `codec.data_path` and the newly added `air_mode` can change while the count is calculated. Moreover, `btusb_work()` calls the helper separately for CVSD and transparent links, so the two counts can represent different moments in the connection state.

I would prefer **one snapshot under the appropriate connection-state lock**, collecting both counts together, and then releasing the lock before any USB PM operation.

This needs a lock-order check; I am not suggesting that `hdev->lock` be held while `usb_autopm_get_interface()` runs.

A second question concerns this policy in patch 2:

```
if (!transp) {
    /* CVSD setting */
} else {
    /* Transparent setting */
}
```

When CVSD and transparent links coexist, transparent mode always wins. Is the selected USB alternate setting guaranteed to carry both types of data adequately? That needs either a specification-based explanation or a mixed-mode emulator test.

The five current scenarios cover important failures, but do not fully settle this choice.

I would also check how notifications are guaranteed to schedule a new work pass if a connection changes while `btusb_work()` is already executing.

**Stable:** defer a stable request until the mixed-mode and synchronization questions are resolved. If accepted, both patches must travel together.

### **10. CO-20 — SCO receive diagnostics**

**Verdict: patch 1 is reasonable; patch 2 should be revised.**

Patch 1 distinguishes allocation failure, an invalid SCO packet length, and an unknown SCO handle.

This is a useful diagnostic improvement. I have no significant objection to the new error classifications or the rate-limited messages.

Patch 2 introduces a weaker inference.

At `drivers/bluetooth/btusb_main.c`, the new logic effectively says:

```
if (data->sco_last_valid &&
    h == data->sco_last_handle)
    err = -ENOTCONN;
else
    err = -ENOENT;
```

But **matching the last successfully received handle does not prove that the rejected packet belongs to a link that has just closed**.

The handle can remain remembered until an alternate-setting change or other cleanup. The code does not directly observe the time of disconnection. A malformed fragment that happens to decode to the remembered handle can also satisfy the condition.

The patch acknowledges some potential misclassification, but its logging and commit message still characterize the result as confirmed post-disconnect residue.

The consequence is that `err_rx` stops counting some packets whose validity has not actually been established.

I recommend one of two approaches: either obtain a bounded record of recently closed handles from the connection layer, or deliberately call the condition a heuristic and avoid treating the packet as definitely harmless.

The latter is simpler but does not fully justify suppressing `err_rx`.

My preference would be to submit patch 1 independently, then reconsider patch 2. The evidence that the original diagnostic is noisy is convincing; the proposed classification mechanism is less convincing.

### **11. CO-43 — Remaining BT-17 recovery series**

**Verdict: do not submit. Two important design risks remain.**

The new series is substantially better than the original B/D combination. The dropped-command scenario is handled, and the deferred-URB memory-ownership work has proper fault-injection evidence.

Nevertheless, I see two unresolved problems.

#### **Blocker 11.1 — The global deferred-command bit is not request-specific**

In patch 2/5, `BTUSB_CMD_DEFERRED` means that some command URB is deferred.

Then `btusb_reset()` uses that bit to infer that the command whose timeout just fired never reached the controller:

```
deferred = test_bit(BTUSB_CMD_DEFERRED, &data->flags);

if (deferred) {
    bt_dev_warn(hdev, "Command not sent; not resetting");
    return;
}
```

This inference is not guaranteed by the bit.

A previous command can have reached the controller and lost its response while another command is deferred. The flag does not identify which command caused the timeout.

The previous version made a similar mistake by using the device's suspended state as evidence that the timed-out command had never been transmitted.

The new bit is a better approximation, but it is still an aggregate state rather than per-command accounting.

I would require a test with multiple pending/outstanding commands where one loses its HCI completion and another becomes deferred. If this state is impossible because of HCI command-credit serialization, that invariant should be demonstrated explicitly for all applicable command-credit configurations.

#### **Blocker 11.2 — D v2 can still lose its queued recovery reset**

Patch 3/5 now does:

```
if (intf == data->intf &&
    btusb_runtime_resuming(data->udev) &&
    !test_and_set_bit(BTUSB_RESET, &data->flags)) {
    usb_autopm_get_interface_no_resume(intf);
    usb_queue_reset_device(intf);
}
```

This improves on the earlier version because it takes a PM reference before queueing the reset.

However, a PM reference is not a guarantee that `usb_queue_reset_device()` will eventually perform a reset.

Its worker uses `usb_lock_device_for_reset()`. That operation can fail, for example because the interface is unbinding or the device lock cannot be obtained. In those cases, the reset work is abandoned.

There is no completion acknowledgment or failure callback to clear the recovery state and release the PM reference.

If the USB interface remains bound after a failed reset attempt, this can leave the reference held and recovery incomplete.

The series should explicitly cover the failure of the **reset worker itself**, not just a failed USB resume.

There is also the already-identified concern that `btusb_reset_resume()` invokes ordinary `btusb_resume()` before the new binding has reinitialized the controller. The firmware-state-loss emulator mode remains important here.

I would keep the USB-core approach to BT-18 open. Adding a btusb-specific callback also changes the `autosuspend_check()` behavior of reset-resume-quirked devices, whether or not the runtime-only reset guard prevents a redundant system-resume reset.

#### **Patches 4/5 — Independent opportunity**

The BT-24 synchronization and BT-25 memory cleanup are stronger standalone candidates.

The new helper correctly addresses the ownership of an unsubmitted deferred URB:

```
static void btusb_free_deferred_urb(struct urb *urb)
{
    kfree(urb->setup_packet);
    dev_kfree_skb_any(urb->context);
    usb_free_urb(urb);
}
```

The kmemleak before/after evidence is significant.

Before extracting these patches, however, check the `btusb_close()` cleanup ordering. It still drains deferred URBs outside `txlock` and clears `BTUSB_CMD_DEFERRED` afterward. The close path needs its own analysis of concurrent senders and shutdown serialization.

**Recommendation:** retain patches 2 and 3 as experimental; consider separating the deferred-URB cleanup and failed-resume synchronization patches after their teardown tests.

### **12. CO-02 v2 — Reusing a closing SCO connection**

**Verdict: patches 1 and 2 are strong candidates; patch 3 should be reviewed separately.**

The ownership fix in patch 1 makes sense. Returning an existing SCO connection without a caller-owned hold can lead to an unrelated socket consuming the first socket's hold on failure.

The comparison to the previously fixed CIS ownership issue is useful historical precedent, and the tests exercise the user-visible regression.

Patch 2 is also substantially improved by folding the earlier race fix into the same commit. The second `abort_reason` check after waiting for an already-running `disc_work` addresses a real scheduling window.

I would make two requests.

First, verify that `cancel_delayed_work_sync(&sco->disc_work)` is always safe with `hdev->lock` held, including less common controller teardown and incoming-connection cases. The current source argument is plausible and the tests are helpful, but this is an important lock-order claim that deserves explicit validation.

Second, patch 2 uses `WRITE_ONCE()` for `abort_reason`, but the existing check at the beginning of `hci_abort_conn()` remains a plain load. Audit all readers rather than instrumenting only the two new reads.

Patch 3 changes the treatment of connections established remotely:

> A link set up by the remote device has no stored parameters from a local connect, so with no holder it is refused once as well.

That is a potential userspace compatibility change. Not every SCO client necessarily retries `ECONNABORTED` in the same way as PipeWire.

I would want an incoming-SCO test where the remote endpoint has already established the connection, followed by a local socket attempting to attach with compatible parameters.

The `-EBUSY` versus `-ECONNABORTED` distinction is defensible for a link that has a known owner, but the no-owner remote-established case needs more evidence.

**My preferred submission structure:** send v2 patches 1 and 2 as the bug-fix series, and make patch 3 a separate follow-up until its incoming-connection semantics are settled. I would not automatically add `Cc: stable` to patch 3.

The 256 MB guest stalls are reasonably explained by the resource-constrained test environment, especially given the 3 GB runs passing 32/32 for each kernel configuration. This is not, by itself, evidence against the SCO changes.

## **Final priorities**

**Lowest-risk upstream candidates**

CO-44, CO-43 E, CO-43 A, the CO-38 kernel patch, CO-26, and the CO-22 stable request.

**Focused pre-send validation**

CO-04 cancellation/unregister paths, CO-05 combined locking, CO-21 mixed-mode and connection-state snapshots, and CO-02 incoming SCO behavior.

**Hold or separate**

CO-38's unrelated failing duration tests, CO-20 patch 2's uncertain classification, and CO-43's B2/D v2 recovery mechanism.

The stable backports in CO-35 have sufficient reported testing to justify asking the stable maintainers to evaluate them. They are a different category of submission from new bluetooth-next code and should remain separate.

### **Evidence limitations**

I read the self-contained dossier and its embedded patches, checked relevant source at the stated kernel baseline through GitHub, independently checked the named upstream commits, and examined relevant mailing-list discussions. I did **not** rebuild these particular patch sets or reproduce their QEMU results independently.

The findings above distinguish source-confirmed problems from concurrency risks needing a targeted test. In particular, the CO-43 global-bit inference and reset-worker failure path remain significant design concerns, but I have not demonstrated a new runtime failure against this latest version.

**Overall decision:** several patches are ready for individual upstream review, but the entire queue is not uniformly ready. The strongest changes are the narrow fixes with a directly reproducible before/after difference. The more complicated recovery and SCO state-management work should remain under review until the identified invariants are established.

No repository changes, submissions, or external communications were made.
