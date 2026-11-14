# Kernel patches ready to send — outside reviewer 7's answer

*Received 2026-11-14 in answer to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes, and one remark outside the patches (reviewer 6), marked
where it stood. What we checked, point by point, is in
`2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.*

---

# Kernel patch submission review — 14 November 2026

**Verdict: send the small, bounded fixes after the corrections below; do not send the entire packet unchanged.** Item 11 contains a system-resume regression. Item 9 needs a coherent, synchronized connection snapshot. Item 10's second patch treats an unbounded last-handle heuristic as proof of a recent disconnect.

This is an independent source review, not a reproduction of the reported QEMU results. No patch was posted, mailed, committed, or pushed.

## Scope and verification

Reviewed [the brief at project commit `facd31e624fe10e912c6e6aefda28d1aa28ef16d`](https://github.com/ivoitovych/qca9377-bt-hang/blob/facd31e624fe10e912c6e6aefda28d1aa28ef16d/reviews/2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md). Its contents are identical to the `main` URL retrieved at the start of this review. Kernel source was fetched independently at bluetooth-next `da3cc02587c629420603df4395179ec82955c941`.

Independent checks performed:

- Extracted all 51 embedded files and verified **51/51 SHA-256 matches** against the brief.
- Applied **18 distinct proposed mainline kernel patches**, individually or in their specified series, to the relevant files fetched at the pinned base. All applied. Item 11 was applied with E and A first.
- Fetched the actual L2CAP source files at `v6.18.63`, `v6.12.117`, and `v6.6.162`; all **six stable backport patches applied** in their specified order.
- Read the relevant btusb, Bluetooth core, SCO, MGMT, command-sync, USB resume, and USB autosuspend code. Checked the original commits named by the principal `Fixes:` tags, the L2CAP upstream pair, the SCI fix, and the ASUS ID commits.
- Consulted upstream stable rules and an overlapping btusb reset-resume proposal and review discussion.

These were file-subtree application checks, not full-tree builds or `git am`/DCO checks. I did **not** run QEMU, hardware tests, KASAN, KCSAN, lockdep, sparse, or the CI bot. Runtime counts below remain the project's reported evidence. I could not independently refresh the stable queues: the attempted GitHub queue paths returned 404 and the kernel.org tree returned 403. Consequently this report does not certify current queue absence or that every upstream thread is still unanswered.

| Item | Recommendation |
|---|---|
| 1 — CO-44 | Send; correct the brief's description, fill the BlueZ link placeholder. Stable is reasonable. |
| 2 — CO-43 E | Send. The locking change is correct; stable is reasonable with the forced-interleaving reproducer explained. |
| 3 — CO-43 A | Send after correcting the commit message's event ordering. Diagnostic only; no stable tag needed. |
| 4 — CO-38 | Send the kernel fix. Separate its regression test from tests awaiting CO-12. |
| 5 — CO-04 | No objection to the specific duplicate-start/UAF repair. Preserve the reproducer limitation and narrow its scope. |
| 6 — CO-05/26 | Send as two patches. State the remaining advertising-list lifetime limitations accurately. |
| 7 — CO-35 | Send the stable requests/backports after correcting the validation wording and refreshing queue state. |
| 8 — CO-22 | Send after refreshing or qualifying the queue-state claim. |
| 9 — CO-21 | Revise before sending: synchronize and combine the connection counts. |
| 10 — CO-20 | Patch 1 is suitable; defer/rework patch 2's residue classification. |
| 11 — remaining CO-43 | Hold B2/D as packaged. Split out the independent discard/leak fixes. |
| 12 — CO-02 v2 | No blocking defect found in the three changes; retain three commits and the folded race fix. |

## 1. CO-44 — timeout status

**Code: no objection.** The base has an explicit `case -ETIMEDOUT` returning `MGMT_STATUS_AUTH_FAILED`; changing the result to `MGMT_STATUS_TIMEOUT` is the appropriate mapping. The historical [161510ccf91c](https://github.com/torvalds/linux/commit/161510ccf91c961638940b03abb1ee804be53a97) introduced precisely that mapping, so the `Fixes:` tag is supported.

Correct this line in the brief:

> “mgmt_errno_status() has no case for it”

It has a case, but the case returns the wrong status. The actual commit message describes that correctly.

I favor `Cc: stable@vger.kernel.org`: this corrects a user-visible erroneous diagnosis, with a narrow change and a targeted negative/positive test. Being visible to userspace is not by itself a reason to leave a bug unfixed in stable. Do not claim that *all* clients merely display the error; the below-the-line discussion appropriately limits that observation to the inspected BlueZ paths.

The 2022 `Link:` is optional supporting history, not evidence that the old value was intentional. It can be dropped without weakening the patch. A shorter subject would be `Bluetooth: MGMT: Report command timeouts correctly`.

The BlueZ test's extra condition ensures that a command was actually intercepted rather than merely obtaining an expected status for an unrelated reason. Replace `@KERNEL_PATCH_LINK@` before posting; the kernel and BlueZ submissions should make their dependency clear.

Source: [mgmt.c, status conversion](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/mgmt.c#L284).

## 2. CO-43 E — deferred anchoring under txlock

**Send.** The critical change is:

> `else` / `usb_anchor_urb(urb, &data->deferred);`

inside the same `txlock` section that observes `BTUSB_SUSPENDING`.

This closes the stated interleaving: a sender cannot observe suspending, let resume drain the anchor and clear the flag, then add an URB to the now-undrained deferred anchor. Replay already obtains the anchor lock under `txlock`; this does not introduce a reverse lock order. `usb_anchor_urb()` does not require sleeping here. Scheduling the waker after unlocking is acceptable: the anchor already owns a reference even if replay gets to the URB first.

The teardown question must be kept separate from the successful-resume race. E does not make every discard path atomic, and does not free the skb/setup packet of discarded deferred URBs. The BT-24 and BT-25 changes address those different defects. That is not a reason to reject E.

The [7bee549e197c](https://github.com/torvalds/linux/commit/7bee549e197c9c0e92b89857a409675c1d5e9dff) attribution is appropriate. I favor stable tagging with the exact schedule and the debug-delay reproduction retained. The ordinary stress test finding no natural occurrence should stay explicit; it does not disprove the demonstrated ordering bug.

Source: [submit_or_queue_tx_urb](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/bluetooth/btusb_main.c#L2388), [play_deferred and resume](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/bluetooth/btusb_main.c#L4989).

## 3. CO-43 A — resume-failure diagnostic

**Code is suitable; fix the message before sending.** This sentence is inaccurate:

> “An HCI command in it then ends in a command timeout two seconds later”

The command timer is already running while `usb_autopm_get_interface()` waits. The packet's own CHECKS table shows command submission at 9.378, command timeout at 11.412, and the new failed-resume log only at 16.533. Thus the timeout precedes the newly logged failure by about five seconds in that run.

Suggested replacement:

> “An HCI command deferred during the resume can time out while the waker is still waiting. Report the runtime-resume error when the PM request returns, so that the command timeout can be correlated with the failed resume.”

Also qualify “the URB stays on the anchor”: the successful USB-level resume can enter `btusb_resume()`, whose receive-submission failure path discards the anchor. Not every negative autopm result implies permanent anchoring.

The wording of the actual log is useful and identifies the failing operation. Suppressing `-EACCES` is reasonable; do not describe it as exclusively a system-sleep error. Rate-limiting would be a defensible refinement if repeated retries generate noise, but it is not a correctness blocker. No `Fixes:` or stable tag is necessary for this diagnostic-only change.

Source: [hci_cmd_timeout](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_core.c#L1525).

## 4. CO-38 — advertising instances

**Send the kernel fix.** Replacing:

> `adv_instance->instance <= hdev->adv_instance_cnt`

with comparison against `le_num_of_adv_sets` repairs the instance-number/count confusion while continuing to hide the reserved mesh instance. The response is initially allocated for the full list count; filtering decreases both the count and the response length. I found no new response-size issue in this change. [b338d91703fa](https://github.com/torvalds/linux/commit/b338d91703fae6f6afd67f3f75caa3b8f36ddef3) introduced the erroneous comparison. Stable is justified for this externally visible one-line fix.

**Do not present the whole BlueZ bundle as a test set that becomes green with CO-38.** Its first patch contains CO-12 duration expectations that still fail on the proposed kernel. The instance-2 test in BlueZ patch 2 currently depends on helpers introduced by patch 1. Extract the needed helpers and this regression case into a standalone test, or explicitly stage the larger suite with the duration work. Sending a test that documents a known kernel bug is possible, but its integration dependency should be an intentional maintainer decision.

No need to block this kernel fix on unrelated BAP functional-test flakes; the controlled base failure and unchanged runtime sources support treating them separately.

Source: [read_adv_features](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/mgmt.c#L8856).

## 5. CO-04 — mesh duplicate start/UAF

**No objection to the targeted handover fix.** Keeping `HCI_MESH_SENDING` set until the locked next-or-idle decision prevents `mesh_send()` from independently queuing the same next request. Removing `mesh_next` from the destroy callback also removes the demonstrated unregister-time callback path into command submission.

The important cancellation distinction is correctly retained:

> `if (err == -ECANCELED) { mesh_send_complete(...); return; }`

The queue-dequeue/clear callbacks can run under `cmd_sync_work_lock`, so blindly adding `hdev->lock` there would invert the ordering used by MGMT submission. In `send_cancel()`, the caller holds `hdev->lock`; the explicit `dequeued` handover covers cancellation of the queued start. The regular command-sync worker calls completion outside `cmd_sync_work_lock`, allowing the new device lock there.

Keep this qualification prominently below the separator:

> “Not tested with syzbot's reproducer; the analysis is from the report and the source.”

That is material evidence, not a weakness to conceal. A deterministic duplicate-queue reproducer or a syzbot test would make this much easier to merge. The patch is a source-supported repair, not a demonstrated successful run of the original reproducer.

Do not describe this as repairing every mesh cancellation behavior. For example, cancellation of an already-running request removes its `mesh_tx`, while the later `mesh_send_done_sync()` still completes whatever is then at the head. A queued successor can consequently be completed without being started. That behavior is visible in the base too; it is an adjacent issue, not a regression introduced here. A useful separate test is A running, B queued, cancel A only, then verify B actually starts and receives its own completion.

The lockdep finding already has its mechanism in the commit message. Its observed 2/35 versus 0/35 frequency belongs below `---`; moving the raw frequency into the main message adds little. `Fixes: b338d91703fa` and stable are reasonable for the UAF fix.

Sources: [MGMT handover](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/mgmt.c#L1092), [sync worker](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_sync.c#L309), [clear/submit](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_sync.c#L675).

## 6. CO-05 + CO-26 — advertising-list locking and failed add

**Send as two patches.** Taking `hdev->lock` around the capacity test, list mutation, and instance selection is appropriate. Releasing it before the synchronous HCI operation avoids holding the device mutex while waiting for events. Carrying only the instance number across that unlock is preferable to retaining an unprotected `adv_info *`.

The second patch's immediate `IS_ERR(adv)` return repairs the error path cleanly and should remain separately reviewable. It is a reasonable member of the same two-patch series. The `b338d91703fa` tags are supported by the original code.

The cover should not claim that `mesh_send_sync()` directly “adds and removes” list entries: the shown function calls `hci_add_adv_instance()`, cancels an advertising timeout, and selects the next instance; it has no direct `hci_remove_adv_instance()` call. Describe the exact operations instead.

The existing qualification about `hci_schedule_adv_instance_sync()` looking up the instance without this lock is important. This patch improves one caller's accesses; it does not establish a complete lifetime protocol for every advertising operation. Nor do clean KCSAN runs prove absence of those remaining races.

Item 5 can be sent separately with a cross-reference. If grouping all three mesh patches, put the handover/UAF repair first, then the list lock, then the error return. There is no reason to merge the last two into one commit merely because they touch the same function. Stable for the locking repair is reasonable; the error-return cleanup is lower priority because the reported externally visible completion does not change.

## 7. CO-35 — stable ECRED backports

**No code objection to the backport adaptations inspected.** I fetched [608e0b7a675b](https://github.com/torvalds/linux/commit/608e0b7a675b2affbbf38167cad0fa63d8e064f7) and [32d86e048d8e](https://github.com/torvalds/linux/commit/32d86e048d8efedb7aa6cbbd3c36c3c435401c92) independently. The backports retain the connection-reference/revalidation loop and the `conn->lock → chan->lock → socket` ordering. The deferred callbacks run after releasing the socket lock. Removing unavailable context annotations and adapting around absent `MSG_ERRQUEUE` handling do not change that intended behavior.

All six backport patches apply to the actual source files at the three stated tags. This does not independently reproduce their runtime results.

**Correct the validation claim before sending.** The covers say:

> “No lockdep or KASAN report with the series.”

But CHECKS says:

> “the tester config has hung-task detection only (no separate lockdep/KASAN build)”

A scan finding no sanitizer report is not sanitizer validation if the instrumentation was not enabled. State the actual configuration: the deferred-accept case passes with hung-task detection, and no hung-task report was observed. Only claim lockdep/KASAN coverage if an explicitly identified instrumented build supports it. Similarly, label the other-case baseline comparison as the earlier pooled comparison, not a newly completed full unpatched run on every current tag.

Keep the pair together and preserve the upstream authors, messages, and sign-off chain. The prerequisite exceeds the stable rule's 100 lines including context, so explicitly requesting an exception for the upstream dependency is appropriate; the cover already does that. This is a maintainer decision, not an automatic reason to invent a smaller stable-only locking implementation.

Keep the [SCI response fix](https://github.com/torvalds/linux/commit/5874f8d03268d34189c6c12c56586b64d26a8bcc) in a separate request: it is a different bug, with different branch applicability. Cross-reference it to explain the full-suite result. The omitted sibling-channel locking fix should remain an explicitly separate limitation; the ECRED pair does not fix every issue in that upstream series.

The named author and Bluetooth maintainer/list Ccs are appropriate. Recheck stable queues before sending. The older 6.1/5.15/5.10 gaps should remain listed; completing those backports is additional work, not something this packet has demonstrated.

Reference: [upstream stable rules](https://docs.kernel.org/process/stable-kernel-rules.html).

## 8. CO-22 — ASUS QCA ROME IDs

**The stable request is justified.** Both fetched upstream commits contain the exact QCA ROME/WBS entries and the authors' reports of LE scanning errors disappearing. The stable rules explicitly allow device-ID additions. There is no need to demonstrate the project's mSBC hang on these ASUS devices to justify their independently reported firmware-loading defect.

The draft already distinguishes the authors' device tests from your own checks. Keep that distinction. Also keep the 6.6 W=1 caveat: a build with `CONFIG_WERROR=n` and an unchanged warning set is not the same result as a warning-free W=1 build.

Correct or refresh:

> “neither commit is in a stable release or in the stable queue (checked 2026-11-14)”

The same packet says 5.15 and 5.10 queue state was last checked on 2 November. The sentence currently overstates the freshness of the seven-line check. I could not independently refresh those queues, so this remains a send-time requirement rather than a verified absence.

The selected order is sensible because the second upstream diff includes the first ID in its context. Send to stable with the original authors and Bluetooth maintainers/list copied. Do not add the unmerged `0cf3:e303` proposal to this request.

Sources: [d54601f21faf](https://github.com/torvalds/linux/commit/d54601f21faf1ab5728e98e2102c3f738be0c177), [cfa67a1dbfd9](https://github.com/torvalds/linux/commit/cfa67a1dbfd9425044f6eef037a114b2d108f436).

## 9. CO-21 — derive the alternate setting from connected SCO links

**Revise the synchronization before sending.** Keeping the negotiated air mode in the core is a sound direction: it describes a connection property, and avoids using a notification for a failed setup as the state of all live links. Keeping that truth solely in btusb would require duplicating the core's connection lifecycle.

The new helper nevertheless reads mutable fields under RCU alone:

> `c->state == BT_CONNECTED && !c->codec.data_path && c->air_mode == air_mode`

And the worker takes two independent snapshots:

> `cvsd = hci_conn_sco_up_num(...CVSD);`
>
> `transp = hci_conn_sco_up_num(...TRANSP);`

RCU protects traversal/object lifetime; it does not make these in-place state updates a coherent snapshot. The event path writes `state = BT_CONNECTED` before assigning the newly added `air_mode`, after the object has already been published. An already-running worker can observe that transition. Separately, CVSD and transparent counts can describe different moments: after the CVSD walk returns zero, a CVSD link can come up and the old transparent link can go down before the transparent walk. Both counts then return zero even though at least one link stayed up throughout.

A later notification may rerun the worker, but it does not make an intervening alt-0 selection and URB stop harmless. This is a source-level race finding; I did not reproduce an audio dropout in a guest.

Take a short `hdev->lock`-protected snapshot of both counts, preferably in one helper with `lockdep_assert_held()`, then release the mutex **before** USB PM or interface-switching calls. Do not hold it over USB I/O. A `READ_ONCE()` on each field alone would not provide the combined snapshot needed here.

Add a controlled transition test that changes the connection set between the present two walks, plus KCSAN coverage for the new field. The five usbip scenarios establish the reported alt-selection fixes, but do not establish this snapshot's synchronization. The mixed CVSD/transparent policy also needs payload/bandwidth validation; merely selecting alt 6/1 is not evidence that simultaneous traffic is carried correctly on every adapter.

After repair, keep the two patches in one series. If targeting stable, mark both or explicitly identify the prerequisite; the driver patch cannot stand alone. The existing `Fixes: baac6276c0a9` is appropriate to the notification-driven selection defect.

Sources: [connection publication](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_conn.c#L1158), [sync completion](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_event.c#L5616), [RCU guarantees](https://docs.kernel.org/RCU/whatisRCU.html).

## 10. CO-20 — receive diagnostics and closed-handle heuristic

**Patch 1: no objection.** Distinguishing allocation failure, length rejection, and unknown handle is useful. Keeping handle validation in btusb is appropriate because it protects USB isochronous reassembly against a continuation fragment being mistaken for a header. Moving that validation entirely to the core would lose the transport-level resynchronization check.

**Patch 2: defer or revise.** This is too strong:

> “A header whose handle is no longer live but equals that handle is data for the link that has just closed”

The code knows only that this was the last *validated* handle. It records neither a disconnect event nor a time/generation bound. The claimed “short window” is therefore not enforced.

Concrete counterexample with CO-21 applied: transparent links A and B use the same selected USB alternate setting; A supplies the last valid header; A closes; B remains up but has not yet supplied another valid header. The worker keeps the same alternate setting, so neither the setting-change clear nor the no-links clear runs. The remembered A handle can remain stale for as long as B is quiet. A malformed frame whose first bits match A is then excluded from `err_rx` and labelled closed-link data without proof. This is distinct from the documented limitation where B overwrites the remembered handle first.

This does not newly deliver the bad frame to the socket—the frame is still dropped—but it weakens the diagnostic counter using an unreliable classification. Send patch 1 independently. For patch 2, either track a bounded, explicit recently-disconnected state and test the two-link case, or soften the logging policy without asserting that the packet is proven residue. The debug line itself is optional; the meaning of `err_rx` is the material decision.

No stable tag is needed for the diagnostic split/heuristic as proposed.

Source: [handle validation and reassembly](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/bluetooth/btusb_main.c#L1523), [alternate-setting change](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/bluetooth/btusb_main.c#L2538).

## 11. Remaining CO-43 — failed runtime resume

### Blocking: D changes system reset-resume behavior

The claim:

> “The system resume path is meant to stay as it is”

does not hold for the submitted code, even if the `RPM_RESUMING` test perfectly distinguishes the two contexts.

At the pinned base, `usb_resume_interface()` does this on reset-resume:

1. If the driver has a `reset_resume` callback, call it.
2. Otherwise set `intf->needs_binding = 1`.

`usb_resume()` subsequently unbinds marked interfaces, and `usb_resume_complete()` rebinds them. Adding the callback removes step 2 for btusb. The proposed callback calls ordinary `btusb_resume()`, but on system resume the runtime-status condition is false, so it neither marks the interface for rebinding nor schedules its own recovery. Ordinary btusb resume restarts URBs; it does not redo the full controller/firmware setup that rebinding previously provided.

**Result:** a system reset-resume that needs reinitialization can retain stale HCI/firmware state and connections. This is a concrete change in control flow affecting the whole driver, not just the emulated QCA ID. Holding the series for this is necessary; documenting “not tested” is not sufficient.

Preserve the old system path explicitly—e.g. a non-runtime branch that marks the relevant interface for rebinding and returns without ordinary-resume replay—or implement a complete, reviewed reset-reinitialization path. The multi-interface ordering must be checked. Simply returning an error from the callback is insufficient: the USB code logs it, and the outer resume loop ignores the interface return value.

Sources: [usb_resume_interface](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/driver.c#L1337), [system resume and complete](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/driver.c#L1647).

### Separate scope change: D enables previously excluded autosuspend

`autosuspend_check()` refuses `USB_QUIRK_RESET_RESUME` devices when an interface driver lacks `reset_resume`, or the interface needs remote wakeup. Registering the new callback removes the first exclusion. In particular, closed adapters with no remote-wakeup requirement can now enter autosuspend where they could not before.

The patch does not mention or test that expansion. Preserve the existing exclusion unless the newly admitted devices are deliberately supported. This needs USB-maintainer review in addition to Bluetooth review.

Source: [autosuspend_check](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/drivers/usb/core/driver.c#L1932).

Relevant outside work exists: [Sean Rhodes's September reset-resume proposal](https://patchew.org/linux/cover.1789679980.git.sean@starlabs.systems/479fdb2638f34ccb02f35a40a34fcdc7cc41ccdf.1789679981.git.sean@starlabs.systems/) explicitly retains `needs_binding` outside its narrow Intel case and preserves the autosuspend exclusion. Oliver Neukum asked about other hardware, S4, and lost connection data. This is useful review precedent, not proof that that proposal is merged or the correct solution here.

### B2, command credits, and series order

Moving the blocking PM acquisition out of the ordered HCI workqueue is reasonable. The current cancellation placement keeps the allocated `hdev`/driver data alive until `reset_work` finishes. Restoring command credit promptly addresses the measured workqueue stall, but credit restoration does not cancel already deferred HCI commands.

Before B2 is sent, add a slow-but-successful resume case: keep resume pending across multiple HCI timeouts, queue distinct commands and repeated opcodes, then let the original resume succeed without reset. Check replay ordering, completion association, and whether timed-out requests can execute after their callers have received failure. The dead-device/reset-recovery matrix does not by itself establish this case. This is a requested validation gap, not a claimed reproduced regression.

The cover explicitly says patch 2 requires patch 3, while placing patch 2 first. Reorder the repaired recovery prerequisite ahead of B2, or combine them if they cannot be meaningfully bisected. “Please apply them together” leaves a known non-working intermediate commit. The same reasoning used to fold CO-02's race fix applies here.

The `RPM_RESUMING` check is not the primary blocker: the udev runtime callback can identify the currently executing runtime-resume path that way. Nevertheless, prefer an agreed USB/PM interface or explicit recorded context over assuming an internal status field alone preserves all reset semantics. Ask linux-usb whether the missing runtime rebind belongs in core before committing to an extra physical reset in every btusb recovery.

### BT-24 and BT-25 should not wait for B2/D

The failed-resume discard/flag-clear critical section is correct in direction and consistent with E's lock ordering. The deferred-free helper correctly owns the URB returned by `usb_get_from_anchor()`, frees its setup allocation and skb, and drops the URB reference; no completion callback will free those payloads for a never-submitted URB. `dev_kfree_skb_any()` is appropriate for its IRQ-disabled callers.

Send these as a small independent series on E, after regenerating their hunks without B2's flag additions and rerunning the focused failure/leak checks. Their faults can be exercised with suitable instrumentation even if the existing reproducer obtains its timing window through B2. The 2009 autosuspend commit and [19cfe912c37b](https://github.com/torvalds/linux/commit/19cfe912c37bbc184c673c3c081edff62ea8e565) support the stated origins. Stable tagging is reasonable for the leak and stranded-URB repairs after upstream review.

## 12. CO-02 v2 — SCO connection reuse

**No blocking defect found in the shown three-patch series.** Retain three commits: caller hold ownership, abort/running-worker synchronization, and parameter compatibility are separately explainable changes. Folding v1's abort check and wait into one patch is the correct choice.

Patch 1 balances the extra ACL hold on reuse and obtains the SCO hold the caller expects. The fetched `8a5b0135d4a5` did add the failure-path drop described in the message. The allocation/link failure path has a separate pending cleanup proposal; coordinate the textual overlap rather than silently absorbing another author's patch into this fix.

For patch 2, the wait under `hdev->lock` is justified for SCO/eSCO at this base: `hci_cancel_connect_sync()` takes the default `-ENOENT` path for those types, and the disconnect worker queues the abort rather than executing the synchronous disconnect under the waiting caller's mutex. The existing connection deletion path already synchronously disables that work. The second check is necessary after waiting, including for a remotely established link newly linked by this call. Keep the two `READ_ONCE()` checks and the paired write.

For patch 3, the early parameter check avoids overwriting the first socket's pending setup before the second socket reaches `sco_chan_add()`. `-EBUSY` for an occupied link and `-ECONNABORTED` for an incompatible unheld link is a reasonable split and is accurately described as a retry opportunity, not seamless codec switching. The historical [10c62ddc6f03](https://github.com/torvalds/linux/commit/10c62ddc6f032c3a096401ca3ce7e5b2d5780859) introduced the unconditional setting assignment.

Keep the message's precise scope—voice setting, codec **id**, and data path. `struct bt_codec` also has `cid`, `vid`, and `num_caps`, which this predicate does not compare. Before extending claims to arbitrary vendor/offload codec identity, audit those consumers and add a corresponding test. I did not establish a currently supported vendor-codec failure from this omission, so it is not a blocker for the demonstrated CVSD/transparent cases.

Stable: retain tags on patches 1 and 2 with the stated introduction/prerequisite constraints. Patch 3 is a real fix and can be proposed for stable, but I favor keeping its first submission untagged until maintainers agree on the reuse/error semantics, followed by a tested stable request. Do not infer backport suitability merely from textual application to older files.

The l2cap results do not establish a series-caused stall, but neither does Fisher p=0.49 prove equivalence. The cover's exact counts and the absence of a SCO connect path in those tests are the right evidence to present. Avoid stronger dossier phrases such as “cannot be involved”; the source review and 3 GB runs support “no causal evidence found.”

Sources: [hci_connect_sco](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_conn.c#L1890), [SCO caller ownership](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/sco.c#L335), [SCO cancel dispatch](https://github.com/bluez/bluetooth-next/blob/da3cc02587c629420603df4395179ec82955c941/net/bluetooth/hci_sync.c#L7924).

## Submission plan

Send items 1–6 after the noted text/test packaging corrections, items 7–8 after honest validation wording and queue refresh, item 10 patch 1, and item 12. Regenerate and send BT-24/BT-25 independently. Hold item 9 for the synchronized snapshot, item 10 patch 2 for its classification policy, and B2/D for the reset-resume corrections and missing success-after-timeout test.

Kernel sign-offs remain the author's sending step, as the brief requests; their absence in this review copy is not counted as a design defect. Keep BlueZ and kernel mail prefixes distinct, retain upstream attribution in stable backports, and do not add review/test trailers on the strength of this source review alone. For the USB recovery discussion, add linux-usb and the relevant USB/PM reviewers; no messages have been sent as part of this review.


---

## Reviewer 7's covering note (sent with the report)

**I would not send the packet unchanged.** Most fixes look suitable, but items 9–11 need revisions.

Full review, with exact quotations, source links, and suggested tests: kernel-ready-to-send-review-2026-11-14.md[kernel-ready-to-send-review-2026-11-14.md](sandbox:/workspace/scratch/92530b08e084/kernel-ready-to-send-review-2026-11-14.md).

The main findings:

- **Item 11 — blocking system-resume regression.** Registering `reset_resume` stops USB core from automatically marking btusb for rebinding. The proposed callback arranges recovery only during runtime resume, so system reset-resume loses its previous reinitialization path. Adding the callback also permits autosuspend for some previously excluded devices.
- **Item 9 — insufficient synchronization.** RCU protects connection lifetime, but the new helper reads mutable connection fields without a coherent snapshot. The two separate counts can report zero active links during a transition even when a link remained active throughout. Take both counts under a short `hdev->lock` section, releasing it before USB operations.
- **Item 10, patch 2 — unreliable classification.** “Last validated handle” does not establish “just-closed link.” With another quiet link remaining on the same alternate setting, the remembered handle can remain stale indefinitely. Patch 1’s diagnostic separation is useful independently.

| Item | Recommendation |
|---|---|
| **1 — CO-44** | Send. Correct the brief: the timeout case exists but returns the wrong status. Stable is reasonable. |
| **2 — CO-43 E** | Send; the anchoring/flag critical section is correct. |
| **3 — CO-43 A** | Send after fixing the message: the observed command timeout precedes the resume-failure log. |
| **4 — CO-38** | Send the kernel fix; separate its regression test from unresolved CO-12 tests. |
| **5 — CO-04** | No objection to the targeted duplicate-start/UAF fix; retain the original-reproducer limitation. |
| **6 — CO-05/26** | Send as two patches, with accurately bounded locking claims. |
| **7 — CO-35** | Backport adaptations look sound. Correct sanitizer-coverage wording and refresh queue checks. |
| **8 — CO-22** | Justified stable request. Refresh or qualify the older queue checks. |
| **9 — CO-21** | Revise the connection snapshot before sending. |
| **10 — CO-20** | Send patch 1; rework/defer patch 2. |
| **11 — remaining CO-43** | Hold B2/D. Separate the deferred-URB discard and leak fixes. |
| **12 — CO-02 v2** | No blocking defect found; retain three commits and the folded race fix. |

I independently verified **51/51 embedded hashes**, checked the relevant pinned kernel sources and historical commits, and successfully applied **18 distinct mainline patches plus six stable backports** to the corresponding source-file subsets.

**Limits:** I did not rerun builds, QEMU, or hardware tests, and could not independently refresh stable queues. Nothing was posted, mailed, or pushed.
