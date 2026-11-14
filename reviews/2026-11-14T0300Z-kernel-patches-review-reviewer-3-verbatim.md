# Kernel patches ready to send — outside reviewer 3's answer

*Received 2026-11-14 in answer to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`.
The text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes, and one remark outside the patches (reviewer 6), marked
where it stood. What we checked, point by point, is in
`2026-11-14T1400Z-kernel-patches-review-answers-checks.md`.*

---

I reviewed the full 6,114-line task, the actual patch files rather than only the summaries, the relevant `bluetooth-next` source at `da3cc02587c6`, the BlueZ side at `20ffd285b58f`, the mainline/stable history, and the current public discussions around the mesh UAF and btusb reset-resume work.

The overall state is good, but I would **not send everything currently grouped under “ready” unchanged**. I found one strong process blocker in CO-35, one definite blocker in the CO-43 remainder that confirms the document was right to keep it off-list, and two cases where I would split the proposed submission before mailing. I did **not** find a correctness blocker in CO-21 after checking an apparent incoming-SCO issue more carefully.

| Item | Verdict | Recommendation |
|---|---|---|
| **1. CO-44 MGMT timeout** | **Ready** | Send kernel patch; I would add `Cc: stable@vger.kernel.org`. BlueZ test separately. |
| **2. CO-43 E deferred-anchor race** | **Ready** | Send. Keep without stable Cc for now. |
| **3. CO-43 A resume-error diagnostic** | **Ready** | Send independently; no Fixes/stable. |
| **4. CO-38 Read Advertising Features** | **Kernel ready; BlueZ 0/3 not ready as one series** | Send kernel fix, preferably with stable Cc. Do not send the three-test BlueZ bundle until CO-12 lands, or extract the CO-38-specific test. |
| **5. CO-04 mesh UAF** | **Technically sendable, one stable/process concern** | Mainline patch looks sound. Test against syzbot reproducer if possible. I would not put `Cc: stable` on this large version; prepare a smaller stable backport after merge. |
| **6. CO-05 + CO-26 mesh advertising** | **Sound, but sequence behind CO-04** | Let CO-04 go first; then rebase/send this pair. |
| **7. CO-35 ECRED stable backports** | **Should repackage before sending** | The requested prerequisite is explicitly over stable's 100-line limit. Backport only the required lock helpers rather than all of `608e0b7a675b`. |
| **8. CO-22 ASUS QCA ROME IDs** | **Ready** | Send stable request. Device-ID additions are explicitly eligible. |
| **9. CO-21 SCO altsetting** | **Ready for review** | Design is valid. I would keep it out of stable on the first posting, then reconsider both patches together after review. |
| **10. CO-20 SCO diagnostics** | **1/2 ready; 2/2 more debatable** | Send patch 1. I would make patch 2 an RFC or explicitly invite feedback on the last-handle heuristic. |
| **11. CO-43 remainder** | **Do not send as series** | D v2 remains unsafe; therefore B2 must also wait. Split BT-24/BT-25 out because those fixes are independently strong. |
| **12. CO-02 v2** | **Patches 1–2 ready; patch 3 should be separate** | Resend v2 as 2 patches; post the new parameter-mismatch fix separately. |

## CO-44: I would send it, with stable Cc

The one-line kernel change remains correct. `-ETIMEDOUT` is lossless for this purpose, unlike `-EACCES`, and the recent upstream `-ERFKILL → MGMT_STATUS_RFKILLED` fix is almost exactly the same species of bug: an hci-sync conversion turned a meaningful MGMT result into the wrong generic status, a tiny `mgmt_errno_status()` mapping corrected it, and a separate mgmt-tester regression test accompanied it. That patch was accepted. [Openwall Lists](https://lists.openwall.net/linux-kernel/2026/10/21/668)

I favor adding:

```text
Cc: stable@vger.kernel.org
```

The current kernel documentation explicitly says a `Fixes:` tag does **not** replace the stable Cc for a stable candidate. CO-44 is tiny, tested, fixes a released-kernel user-visible error, and is not a speculative race. [Linux Kernel Documentation](https://docs.kernel.org/process/submitting-patches.html)

So here I would choose the package's stable variant.

## CO-43 E and A: both clean

I found no new issue with E. The important locking fact is still sound: after the change, the decision “this URB must be deferred” and the actual insertion into `data->deferred` happen under the same `txlock` that serializes successful resume's drain/clear operation. The existing order is `txlock → usb_anchor` in `play_deferred()`, so E introduces no new lock-order reversal.

I would **not** add stable Cc to E yet. The source race is real and your widened-window reproducer demonstrates it, but the stable rules explicitly discourage theoretical races unless there is a real manifestation; this one has not been observed naturally. [Linux Kernel Documentation](https://docs.kernel.org/next/process/stable-kernel-rules.html)

A is even less controversial: useful diagnostic, no semantic change, no Fixes, no stable.

## CO-38: kernel yes, current BlueZ 0/3 no

The kernel one-liner is correct:

```diff
- if (adv_instance->instance <= hdev->adv_instance_cnt) {
+ if (adv_instance->instance <= hdev->le_num_of_adv_sets) {
```

The existing comment describes precisely the latter quantity: the externally visible instance-number range is determined by the controller's number of advertising sets, not by how many list entries currently happen to exist. The “1 removed, 2 remains” case is a particularly clean regression test.

I would add stable Cc to the kernel patch. It is a two-line behavioral correction originating in `b338d91703fa` and the reproducer is deterministic.

I would **not send the BlueZ `[PATCH BlueZ 0/3]` in its current form**, however. Patch 1/3 deliberately installs timeout tests of which the 66-second/overflow cases are known to fail current kernels until the separate CO-12 duration-overflow kernel fix exists. That couples an immediately ready CO-38 test with a not-yet-fixed independent kernel defect.

The clean choices are to wait for CO-12 before sending that 0/3, or to extract the minimum framework plus `Add Ext Advertising - Instance 2 listed alone` into a small CO-38-specific BlueZ patch. I prefer the second if you want CO-38 to move now.

## CO-04: your mesh UAF design is substantially better than the pending alternative

The public syzbot issue is still open and describes exactly the duplicate-queue → freed `mgmt_mesh_tx` → second `mesh_send_sync()` UAF that your patch addresses. Igor Putko's October proposal attacks the same race by introducing `hdev->lock` around the handoff. [Syzbot](https://syzbot.org/bug?extid=f20755f37da70df33a16)

Your version has an important advantage: it has actually reasoned through `cmd_sync_work_lock`. In particular, the `-ECANCELED` path deliberately avoids taking `hdev->lock`, and `mesh_send_done_sync()` no longer leaves a destroy callback that can reenter queue submission while command-sync teardown locks are held. Given the lockdep reversal you reproduced against the simpler alternative, that difference is substantive.

I also rechecked the `mesh_next()` queue-error path after initially suspecting a loop. It is okay:

```c
while ((mesh_tx = mgmt_mesh_next(hdev, NULL))) {
        if (!hci_cmd_sync_queue(...)) {
                ...
                return;
        }

        mesh_send_complete(hdev, mesh_tx, false);
}
```

A failed queue removes that request before looking again, so it cannot spin forever on the same object.

One behavioral question remains: if queueing repeatedly fails, the loop can complete/drop several pending packets rather than only the first. I don't see a safety problem in that, but I would mention it if a reviewer asks why this is a `while` rather than a single handoff attempt.

The biggest weakness is simply that this exact implementation has **not been run against syzbot's reproducer**, despite the public reproducer being available. Your KASAN/lockdep testing is strong enough to send, but a `#syz test` result would materially improve the submission.

I would reconsider the current `Cc: stable`. The patch's diff is **169 lines including context**, while the current stable rules say a stable patch cannot exceed 100 lines with context. [Linux Kernel Documentation](https://docs.kernel.org/next/process/stable-kernel-rules.html) I would rather get this version reviewed/merged in mainline and then produce the smallest equivalent stable backport possible than knowingly nominate a version outside the documented limit.

## CO-05 + CO-26: technically good, but send after CO-04

Patch 1 fixes a straightforward contract violation: `hci_add_adv_instance()` expects the advertising state to be protected, while `mesh_send_sync()` currently manipulates it outside `hdev->lock`. Releasing the mutex before `hci_schedule_adv_instance_sync()` is also correct; you must not hold `hdev->lock` through HCI synchronous command traffic.

Patch 2 is also straightforward. Currently:

```c
adv = hci_add_adv_instance(...);
if (IS_ERR(adv))
        err = PTR_ERR(adv);

...
return hci_schedule_adv_instance_sync(...);
```

throws away the useful `hci_add_adv_instance()` failure and then tries to operate on an instance that was never added. Returning the original error is the appropriate behavior.

The remaining unlocked accesses inside `hci_schedule_adv_instance_sync()` are a broader shared-helper issue, not a reason to leave this direct caller violation unfixed.

What I would change is **submission order**. CO-04 and CO-05 both alter `mesh_send_sync()`, and CO-04 is a live syzbot UAF. Sending both independently at once creates needless review/rebase conflicts. Send CO-04 first. Once Luiz's tree contains it, rebase CO-05/26 onto that result and send the pair.

## CO-35: this is the one package I would actually rework before stable mail

Your diagnosis and testing are excellent. I independently checked both upstream commits:

`608e0b7a675b` introduces `l2cap_chan_lock_conn()` / `l2cap_chan_unlock_conn()` together with the wider `l2cap_chan_close_unlocked()` refactoring.

`32d86e048d8e` uses those locking helpers to move deferred acceptance out from under the socket lock and fixes the self-deadlock.

The problem is procedural but explicit: your own cover says the prerequisite is a **149-line diff**, whereas current stable rules say the patch “cannot be bigger than 100 lines, with context.” [Linux Kernel Documentation](https://docs.kernel.org/next/process/stable-kernel-rules.html) Asking the stable maintainers to waive a rule while simultaneously pointing out the violation is unlikely to be the strongest submission.

More importantly, `32d86e048d8e` does **not** need the whole first commit. It needs only:

```c
bool l2cap_chan_lock_conn(struct l2cap_chan *chan);
#define l2cap_chan_unlock_conn(...)
```

The `__l2cap_chan_close()` refactor, `l2cap_chan_close_unlocked()`, call-site conversions, and export are unrelated to the ECRED deadlock.

I would therefore make the stable package a two-patch adapted backport:

```text
1/2 Bluetooth: L2CAP: add connection-aware channel locking helpers
    [subset of upstream 608e0b7a675b needed by the following fix]

2/2 Bluetooth: L2CAP: hold conn->lock for __l2cap_ecred_conn_rsp_defer
    [backport of upstream 32d86e048d8e]
```

Document very explicitly that 1/2 is a reduced prerequisite extracted from upstream `608e0b7a675b`, with no semantic changes to those helpers. That is preferable to inventing new stable-only locking and preferable to submitting unrelated portions of a 149-line mainline refactor.

I would do this for **7.3 too**, instead of requesting the oversized upstream prerequisite verbatim. Your separate `5874f8d03268` SCI request is correct and should remain separate; it fixes a genuinely independent 7.3 problem.

The older 6.1/5.15/5.10 lines should remain a later job because you've already established that their source shape needs a different backport.

## CO-22: yes, send the ASUS QCA ROME stable request

I independently fetched both mainline commits. `d54601f21faf` is not speculative: on ASUS `0b05:1868`, the generic match fails to apply `BTUSB_QCA_ROME`, so the QCA rampatch/NVM are not loaded; the author tested the quirk on the actual device. `cfa67a1dbfd9` does the same for ASUS `0b05:1825`, also with real-hardware testing.

This is exactly the category stable explicitly permits: the current rules say eligible patches may “just add a device ID.” [Linux Kernel Documentation](https://docs.kernel.org/next/process/stable-kernel-rules.html)

So the request does not need to argue that those machines necessarily reproduce your BT-17 hang. The sufficient argument is that mainline has tested device IDs required to put those controllers on their correct QCA ROME driver path, and the additions are absent from supported stable trees.

I would send CO-22 as written.

## CO-21: after rechecking, I think this pair is ready for review

The central design is good. `conn->setting` is the host's requested voice setting and can be stale or absent; the Synchronous Connection Complete event's `Air_Mode` is what the controller says the established link actually uses. Persisting that result in `hci_conn::air_mode` is therefore a more trustworthy source for a driver trying to size its USB isochronous transport.

Your worker also fixes the conceptual bug in the old notification interface: instead of “the last event says CVSD/transparent/disable,” it recomputes state from **all currently connected HCI-path SCO/eSCO links**.

I had initially worried that incoming links would fail to schedule the final recount because `conn->setting` was not populated. That concern was wrong: an unset setting is zero, and `SCO_AIRMODE_CVSD` in the existing setting namespace is zero, so the current cleanup path still emits the generic `HCI_NOTIFY_DISABLE_SCO`. Because DISABLE carries no codec information and patch 2 merely treats it as “schedule a recount,” that path works.

The only remaining review question is the helper:

```c
rcu_read_lock();
list_for_each_entry_rcu(c, &h->list, list) {
        if (... c->state == BT_CONNECTED &&
            !c->codec.data_path &&
            c->air_mode == air_mode)
                num++;
}
rcu_read_unlock();
```

RCU protects object/list lifetime, not a coherent snapshot of mutable `state`, `codec.data_path`, and `air_mode`. In practice the relevant writes are serialized by `hdev->lock` and the worker is ordered from the notifications after the state is published, so I do not see a demonstrated bug. Still, I would either add a short comment documenting that publication/notification ordering or consider taking `hdev->lock` around the count if doing so is safe in the btusb work context. This is a **review question, not a blocker**.

I would not add stable Cc to v1 of this redesigned two-subsystem series. Let it get core/driver review first. If accepted unchanged, the pair can then be evaluated together for stable.

## CO-20: patch 1 stronger than patch 2

There is real historical and current justification for distinguishing these cases. Existing btusb history explicitly recognizes two different phenomena: bogus-looking handles caused by losing isochronous framing, and a few sane old-handle packets around connection teardown that are harmless late data. [Upd.dev](https://upd.dev/torvalds/linux/blame/commit/1ffdb51f28e8ec6be0a2b812c1765b5cf5c44a8f/drivers/bluetooth/btusb.c)

Patch 1 is therefore useful on its own. It turns one misleading `"corrupted SCO packet"` into actionable distinctions while preserving `err_rx` accounting.

Patch 2 is more subjective. “Same as the last valid handle” is a good heuristic for your observed late-packet case, but it is not proof of provenance. As the commit message correctly admits, a misaligned fragment in that short window can happen to decode to the same handle and will then be demoted from an error. With multiple SCO links, genuine late data may also remain classified as unknown simply because another link became “last”.

Nothing dangerous follows — this is log/stat classification — but I would either send 1/2 alone first or label the pair RFC enough that reviewers are explicitly choosing this heuristic. I would not present 2/2 as mechanically obvious.

## CO-43 remainder: D v2 has a decisive flaw

The document already says this series is “for review, not yet to send.” That remains the right decision.

D v2 says:

> “The system resume path is meant to stay as it is”

but adding:

```c
.reset_resume = pm_ptr(btusb_reset_resume),
```

means the system reset-resume path **cannot stay as it is**, regardless of the `RPM_RESUMING` condition inside the callback.

The USB core's decision happens at the existence of the callback. Without `reset_resume`, a reset-resumed btusb interface is marked `needs_binding`; with the callback present, the core calls it instead and does **not** mark that interface for the normal rebind fallback. Your test:

```c
if (btusb_runtime_resuming(...))
        usb_queue_reset_device(...);
```

only controls the extra reset you queue. It does not restore `needs_binding` on a **system** reset-resume.

That reproduces the architectural mistake Linux already made once. In 2013 generic `.reset_resume = btusb_resume` was added, then reverted because USB reset can leave some Bluetooth devices in a state that requires re-enumeration/userspace setup; the revert fixed actual suspend/resume failures. [Linux-Kernel Archive](https://lkml.indiana.edu/1311.3/01913.html)

The very recent Intel work reinforces this: its reset-resume behavior is deliberately restricted to **closed, fixed Intel adapters on ACPI-manageable ports**, while running HCI and other adapters retain rebind behavior. [Openwall Lists](https://lists.openwall.net/linux-kernel/2026/09/17/3066)

So D v2 is a **blocker**, not merely “needs system-suspend testing.” The runtime/system discriminator doesn't solve the callback-existence problem.

Consequently, B2 also cannot go yet because its commit message and successful-reset-resume behavior explicitly depend on D.

By contrast, BT-24 and BT-25 are valuable independent fixes. I would extract them from this series, rebase them without `BTUSB_CMD_DEFERRED`/D dependencies, and send them separately. BT-25 in particular now has a source proof **and** kmemleak reproduction. The recent upstream `btusb_reset()` PM-reference fix is also a reminder that PM/reset ownership in this driver has produced real bugs recently. [Kernel Git Repositories](https://kernel.googlesource.com/pub/scm/linux/kernel/git/bluetooth/bluetooth/%2B/c93922dd316b7273a8667d29084632066fa8a2d3)

## CO-02 v2: I would make v2 a two-patch series

Patches 1 and 2 are strong.

Patch 1 closely follows the already accepted CIS ownership correction `e06d549fcd4a`: an existing link changes what `hci_conn_link()` does, so the parent/caller hold bookkeeping has to be balanced explicitly. Your SCO version is consistent with that established ownership model.

Patch 2 also closes the race that v1 left between `cancel_delayed_work()` and an already-running `hci_conn_timeout()`. Folding the second `abort_reason` check into the same patch was the right v2 change. I agree with `-ECONNABORTED` there: the object is already committed to teardown, and returning immediately is preferable to reporting a connected socket that the old Disconnection Complete will destroy moments later.

Patch 3 is plausible and your new tests are convincing, but it is **new work**, with an older `Fixes:` origin and a user-visible choice between `EBUSY` and `ECONNABORTED`. I don't see a hard correctness bug in it; `refcnt` is being used as a connection-holder count, not a lifetime kref. Still, the commit message should say “while the connection has a holder” rather than make the stronger general claim that a nonzero generic `hci_conn::refcnt` necessarily means “a socket holds it.”

More importantly, adding patch 3 to the resend gives reviewers a reason to hold an otherwise mature fix series. I would send:

```text
[PATCH v2 0/2] Bluetooth: hci_conn: fix SCO connection reuse
  1/2 hold a reused SCO connection for its caller
  2/2 don't reuse an aborting SCO connection
```

and send the parameter-preservation change as a separate patch/thread. Keep stable Cc on 1 and 2 as currently prepared; keep it off the new parameter patch.

## My proposed actual send queue

At this point I would send **CO-44, E, A, CO-38 kernel-only, CO-04, CO-22, and CO-02 v2 patches 1–2**. I would send **CO-21** too after the small helper-locking wording/check, but I would not hold the whole queue for it. CO-05/26 should wait only long enough for CO-04 to establish the new `mesh_send_sync()` base. CO-35 should be repackaged to comply with the stable size rule. CO-20 patch 1 can go independently; patch 2 deserves an RFC-style presentation. CO-43 B2/D should stay local, while BT-24/25 should be extracted and turned into their own clean series.

The most important new result from this review is therefore **not a new kernel bug in the patches marked ready**. It is that **CO-43 D v2 still cannot preserve system reset-resume semantics merely by checking `RPM_RESUMING`, because registering `reset_resume` itself suppresses USB core's `needs_binding` fallback**. That is the architectural issue I would resolve with linux-usb before doing any more work on B2/D.
