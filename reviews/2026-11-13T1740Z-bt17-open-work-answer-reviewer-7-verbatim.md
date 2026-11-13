# BT-17 open work — outside reviewer 7's answer to the task document

*Received 2026-11-13 in answer to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md`. The
text is kept as received, except for the reviewer's tooling marks, which
`scripts/review-text-clean.py` removes. What we checked, point by point, is in
`2026-11-13T1750Z-bt17-open-work-answers-checks.md`.*

---

## The report

# BT-17 open-work review — 13 November 2026

Reviewed the [1740Z brief](https://github.com/ivoitovych/qca9377-bt-hang/blob/a5270f90152c42e4996f3ce15b843d2d5bd26e29/reviews/2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md), the relevant kernel files at `bluez/bluetooth-next` commit `da3cc02587c629420603df4395179ec82955c941`, and upstream history. BlueZ source review used `20ffd285b58facfd1f2478d159a5f941b09d5be1`.

This is a source and history review. I did not run the guest, a kernel build, real hardware, or kmemleak. Results quoted from the brief remain the project's results. The companion diff is a review candidate, not a tested recovery implementation.

The strongest new results are: the runtime-rebind gap has explicit 2021 precedent; HCI Reset timer suppression has an explicit 2011 command-ordering rationale; and the deferred cleanup leak includes the first rejected URB in `play_deferred()`, not just the remaining anchor contents. A correct B replacement needs recovery coordination with T2, rather than another suspended/active predicate.

## Findings

Line numbers below refer to the unpatched kernel commit above.

| Severity | Location | Finding and evidence |
|---|---|---|
| Blocker for B replacement | `drivers/bluetooth/btusb_main.c:1095`, `:2388`; `net/bluetooth/hci_core.c:1526` | Neither PM state nor a nonempty deferred anchor identifies whether the timed-out command reached the controller. The anchor can contain ACL traffic or a different command. Source analysis; the brief's `dropcmd-wedge` results demonstrate the completed-USB-transfer counterexample. |
| Should-fix | `drivers/bluetooth/btusb_main.c:2238`, `:4999`, `:5013`, `:5075` | Deferred cleanup leaks skb ownership; the scuttle paths also leak command setup packets. The URB already removed from the deferred anchor when `usb_submit_urb()` fails must be freed separately. Source finding; no leak measurement here. |
| Should-fix | `drivers/bluetooth/btusb_main.c:2394`, `:5075` | Failure cleanup and clearing `BTUSB_SUSPENDING` must be one transaction with deferred insertion. This requires E as well as locking the failure drain. Otherwise a sender that made its decision before the drain can still insert afterward. Source finding. |
| Question, with concrete prior art | `drivers/usb/core/driver.c:1337`, `:1963`, `:2022` | Runtime reset-resume can mark an interface for rebinding without arranging rebind. Commit `811ae81320da` explicitly describes this failure for btusb under a different reset trigger. It does not establish the original QCA hardware cause. |
| Blocker for a proposed timer-based T4 fix | `net/bluetooth/hci_core.c:4351`; `net/bluetooth/hci_sync.c:4005` | Removing the `HCI_RESET` timer exception would undo an intentional command-ordering fix. Recovery should be considered after failed initialization has unwound, without releasing ordinary command traffic while Reset remains unresolved. |
| Should-fix in test coverage | `drivers/usb/core/hub.c`, `usb_reset_and_verify_device()`; harness `bt17-emu.py` SET_CONFIGURATION handling | SET_CONFIGURATION is an observation of one successful reset path, not a unique or complete reset notification. It is too late to model all firmware-state loss during reset. |
| Nit in requested CO-44 note | `net/bluetooth/mgmt.c:218`, `:284`, `:314` | “No answer” is not an entry in `mgmt_status_table`. It becomes `-ETIMEDOUT` through the synchronous command path. Say that the change makes that outcome consistent with timeout statuses in the table. |

## T1 — Replacement for B

### The predicate

`!usb_anchor_empty(&data->deferred)` under `txlock` is a stable observation of the queue only if all producers use that lock (E). It is not a predicate about the timed-out command. Even an opcode match is insufficient when an opcode can recur. A reliable per-command test needs a submission identity/generation that survives cancellation and late completion.

For **runtime autosuspend**, the driver rejects suspension while `tx_in_flight` is nonzero. The counter is incremented under `txlock` before the submit path, so it also covers the interval between deciding to submit and actually submitting. After USB completion the counter drops, even if no HCI Command Complete/Status has arrived. That is exactly why the controller may autosuspend before its HCI command timeout. For **system suspend**, the automatic-suspend check does not apply: in-flight traffic can exist when suspension starts and is subsequently killed. Do not generalize the runtime invariant to system sleep.

### Mechanism and sketch

Move the potentially blocking PM/recovery work off the ordered HCI workqueue, but coalesce it with USB's reset/rebind outcome. `pm_runtime_get_if_active()` avoids a snapshot/refcount race only for its narrow operation; returning zero for a sleeping device still loses the `dropcmd-wedge` recovery. `usb_autopm_get_interface_async()` schedules a resume and takes a usage reference; it does not tell the caller when recovery may safely reset or rebind.

The following is a **design sketch, not an existing API or buildable patch**:

```c
/* Timeout callback: no synchronous runtime resume here. */
request_recovery(usb_device_ref, interface_number, binding_generation);
/* Coalesce requests and gate new command transmission for this generation. */

/* Core-owned recovery worker, outside both HCI workqueues. */
resume_and_pin_device();
wait_for_relevant_pm_callbacks_to_finish();
lock_usb_device();
if (device_gone || binding_generation_changed)
        finish_without_reset();
else if (interfaces_need_binding)
        unbind_all_marked_then_rebind_all();
else
        reset_device_once();
unlock_usb_device();
release_pm_and_object_references();
```

The lifetime and PM-ordering implementation is still open. A worker merely added to `btusb_data` is not sufficient: reset may disconnect and free that data; synchronous cancellation in disconnect can deadlock if the worker is waiting for the USB device lock that disconnect holds. Likewise, a worker calling a reset which invokes its own cancellation can deadlock. A core-owned USB object/reference and explicit binding generation are one plausible design, not an established solution.

After PM completes, checking only `needs_binding` is still insufficient: another worker may already have rebound the interface and cleared that flag. The generation check must make work for the old HCI instance obsolete. Do not dereference an old `hdev` simply because the USB device still exists.

### Command credits and failure cases

Making `hdev->reset()` return promptly restores `cmd_cnt` earlier in the present `hci_cmd_timeout()`. Therefore this is a scheduling change, not merely moving a slow call. New commands must not accumulate behind a recovery operation and later be replayed after their requests have timed out. The design needs an explicit policy to reject/cancel requests while recovery is pending, with correct request identity; clearing a bit alone cannot supply that policy.

| Scenario checked by source reasoning | Required result |
|---|---|
| Resume never answers | Timeout callback returns promptly; worker can wait independently; disconnect terminates the recovery generation. |
| Command USB-completed, no HCI response, device autosuspended | Resume, then issue one recovery reset if the same binding survives and USB did not already reset it for rebind. |
| Persist reset-resume succeeds | Rebind marked interfaces without issuing another USB reset. |
| Rebind finishes before timeout recovery examines the device | Old generation becomes a no-op. |
| PM disabled/system transition | Defer through the PM lifecycle; do not equate disabled runtime PM with a usable device. |
| Concurrent timeouts | One recovery per generation, bounded failures, no uncontrolled reset loop. |
| Disconnect while worker waits | No stale data dereference and no lock/cancel cycle. |

I am not sure maintainers would accept three independent timeout delays as the final behavior. [Commit `7c393421755d`](https://github.com/torvalds/linux/commit/7c393421755daf35ae1e4e0016b99f308123751a) removed btusb's multiple-timeout threshold because only one command is in flight. That favors prompt, coalesced recovery, although it is not a ruling on this proposal. T1 is not merge-ready until the lifetime, request cancellation, and T2 coordination are implemented and tested.

## T2 — Runtime rebind and the USB question

The known-quirk autosuspend gate is real: `autosuspend_check()` rejects reset-resume-quirked devices when the required callback or wakeup conditions are unsuitable. It cannot predict every ordinary resume that later falls back to persist reset-resume. This supports the proposed explanation of the asymmetry; it does not prove that the fallback gap was an intentional policy.

There is unusually direct prior art: [commit `811ae81320da`](https://github.com/torvalds/linux/commit/811ae81320da53a5670c36970cefacca8519f90e), “xhci: Remove CONFIG_USB_DEFAULT_PERSIST to prevent xHCI from runtime suspending” (2021), explains that btusb stops working after a runtime reset because the system-resume completion path that forces rebinding is absent. That fix prevented the relevant host-controller runtime suspend. It did not add generic runtime rebind. The commit links [the submission](https://lore.kernel.org/r/20211210141735.1384209-2-mathias.nyman@linux.intel.com); I verified the commit message, while direct retrieval of that lore URL was blocked.

Inline rebind is unsafe as a simple substitution. `usb_unbind_interface()` itself calls synchronous autoresume. Re-entering this while its parent/device runtime-resume transition is in progress can wait on that same transition. A runtime resume initiated through an interface also raises child-PM completion ordering. Unbinding btusb calls HCI unregister/close and can wait on HCI work that is itself waiting for the current PM operation. Acquiring the USB device mutex alone does not eliminate those cycles.

A deferred core operation is the better direction to discuss. It needs USB-object references, a PM pin, ordering after relevant callbacks return, device locking, and the existing **unbind all, then rebind all** ordering for composite drivers. It must handle disconnect and system sleep's `is_prepared` restriction. Failing resume alone is not a complete recovery policy: it can leave a bound but unusable interface and a runtime-PM error. Logical disconnection/re-enumeration would be an explicit alternative with different user-visible effects.

A genuine btusb `reset_resume` is another substantial design: it must restore vendor firmware and controller configuration, account for lost connections and outstanding commands, and keep ordinary HCI traffic quiescent until usable. Calling `btusb_resume()` and queueing another reset does not achieve that. Nor is calling an arbitrary `hdev->setup()` synchronously in a PM callback safe: vendor setup can need HCI commands and paths blocked by that callback.

### Draft question — not sent

```text
To: linux-usb@vger.kernel.org
Cc: linux-bluetooth@vger.kernel.org
Subject: USB runtime reset-resume leaves btusb interfaces marked needs_binding

On bluetooth-next da3cc02587c6, a successful persist reset-resume after
a failed runtime resume can leave btusb bound but unusable. btusb has
no reset_resume callback, so usb_resume_interface() sets needs_binding.
usb_runtime_resume() has no corresponding unbind/rebind completion step.

I can reproduce this with a USB/IP device emulator: hold the first
resume GET_STATUS until timeout, then let reset-resume succeed. A
close-initiated resume avoids depending on btusb's command-timeout reset.
The kernel reports:

  usb 2-1: retry with reset-resume
  usb 2-1: reset full-speed USB device number 2 using vhci_hcd
  btusb 2-1:1.0: no reset_resume for driver btusb?
  btusb 2-1:1.1: no reset_resume for driver btusb?
  Bluetooth: hci0: HCI reset during shutdown failed

The device answers subsequent USB requests, but powering Bluetooth on
again times out. btusb_resume() was skipped and BTUSB_SUSPENDING remains
set. This resembles the missing runtime rebind described in 811ae81320da,
although here persist fallback, not XHCI_RESET_ON_RESUME, triggers it.

The autosuspend gate for USB_QUIRK_RESET_RESUME does not cover this
unexpected fallback. Should USB core queue unbind/rebind after the PM
callbacks have unwound, without another port reset? Or should this case
fail resume and arrange logical disconnect/re-enumeration?

I would appreciate guidance on the PM and device-lock ordering, including
resume initiated through an interface. Inline rebind can re-enter PM via
unbind, while btusb unregister can wait for work blocked on that resume.
```

The draft's “I can reproduce” refers to the supplied project reproduction and is intended for its operator to send. The excerpt is from `base-m-close-1.log` in the brief, not a new run. Add the public reproduction URL and relevant maintainers from `scripts/get_maintainer.pl` before sending.

## T3 — Race and ownership cleanup

The leak follows from ownership, without needing a timing race. A successfully deferred send returns success to HCI, transferring skb responsibility to the driver. Its URB has not been submitted, so no USB completion will free `urb->context`. `usb_scuttle_anchored_urbs()` drops URB references; URB destruction does not free either the context skb or setup packet. These allocations also do not become owned by USB merely because an attempted later submit fails.

[Commit `19cfe912c37b`](https://github.com/torvalds/linux/commit/19cfe912c37bbc184c673c3c081edff62ea8e565), “Bluetooth: btusb: Fix memory leak in play_deferred” (2017), fixed anchoring/URB-reference and setup-packet handling. It is relevant precedent, but does not supply the missing skb cleanup in this tree.

The companion `BT17-deferred-cleanup-candidate.diff` applies directly to `da3cc02587c6` and includes E's producer-side locking change. Do not apply it unchanged on top of E. It:

1. Introduces a helper that frees setup packet, skb with `dev_kfree_skb_any()`, and the caller's URB reference.
2. Drains the deferred anchor under `txlock` at close and failed resume.
3. Makes failed-resume drain and clearing `BTUSB_SUSPENDING` atomic with insertion.
4. Frees both the first rejected `play_deferred()` URB and all remaining deferred URBs.
5. Preserves the `!HCI_RUNNING` resume path by draining there only when there is an actual resume error.

No `tx_in_flight` decrement belongs in this helper: these URBs were never successfully submitted by `play_deferred()`, which increments the counter only after success. Do not call `btusb_tx_complete()` manually: it would falsely perform completion accounting and acquire `txlock` again. Close relies on the existing HCI close sequence quiescing transmission; the new lock does not independently prohibit future senders after close.

Do not add unconditional `hci_cmd_sync_cancel()` to the free loop. It acts on the current synchronous request, not a request token carried by the discarded URB; an old deferred command may outlive its requester. Correct error completion is desirable, but requires correlation and belongs with recovery/request-lifetime work. This candidate fixes memory ownership and the specified enqueue/drain race; it does not make a partially failed resume healthy or provide immediate per-command error reporting.

The interrupt/bulk resume helpers can fail allocation or synchronous submission, including shutdown/device-state failures. An emulated asynchronous completion error is not a synchronous `usb_submit_urb()` failure. Use a controlled kernel allocation or enqueue failure hook to reach the exact branch.

Validation here: `git apply --check` passed against the fetched base file. `checkpatch.pl --no-tree --strict --no-signoff` reported zero errors, warnings, or checks across 92 lines. Its auxiliary spelling and const-structure databases were unavailable. No compile or runtime validation was performed. Before upstream submission, split E from the cleanup/race work so each problem and prerequisite is reviewable.

## T4 — HCI Reset timeout history

[Commit `7bdb8a5cf17f`](https://github.com/torvalds/linux/commit/7bdb8a5cf17f66614a9897645efcd4ccc27535ee), “Bluetooth: Don't use cmd_timer to timeout HCI reset command” (2011), explicitly fixes slow-reset controllers receiving the next command before Reset Command Complete. Therefore the timer exception is intentional. [Commit `600b21507eb6`](https://github.com/torvalds/linux/commit/600b21507eb64bcd85bb87d06c2c2c451b565f02) later fixes an `HCI_RESET`/command-credit race, further showing that this flag participates in command sequencing.

Driver-specific timeout handling arrived later in [commit `e2bef3847e3d`](https://github.com/torvalds/linux/commit/e2bef3847e3d0d57dcf316de50c4b1a5a91816b7) (2019); btusb's QCA port-reset recovery followed in [commit `6933568aec92`](https://github.com/torvalds/linux/commit/6933568aec92dd6432207baaf59378d01f55a14f) (2020). The earlier timer suppression explains why that later hook is not reached. It is not evidence that maintainers deliberately rejected transport recovery after initialization failure.

I would propose bounded recovery after a failed power-on Reset has completed the synchronous failure/unwind path. `hci_dev_open_sync()` already flushes work, purges queues, and closes after failed initialization; the actual recovery must also avoid locks held by its caller and workqueue self-waits. Queue recovery after those dependencies are released. Limit retries across a recovery generation to avoid repeatedly reprobeing dead hardware. Keep the existing command timer exception.

Required tests: a slow but successful Reset must not release the next command prematurely; a permanently unanswered Reset should fail its request and trigger at most the intended bounded transport recovery; late Reset completion, concurrent power-off, and disconnect must not revive an obsolete request. Not sure of the best upstream API boundary without implementing and checking the callers.

## T5 — Research results and limits

### Relevant history

| Source | Relevance |
|---|---|
| [`7bee549e197c`](https://github.com/torvalds/linux/commit/7bee549e197c), original btusb autosuspend support | Introduces the deferred-anchor and in-flight-counter design. Supports E's existing Fixes tag. |
| [`04b8c8143d46`](https://github.com/torvalds/linux/commit/04b8c8143d46453a443ac32bfcd76ec952605765) | Realtek firmware loss across resume and use of reprobe to reload it. |
| [`9e45524a0111`](https://github.com/torvalds/linux/commit/9e45524a0111) | Realtek remote-wakeup/power behavior distinguishes runtime retention from system-sleep firmware loss. Do not turn its system-resume policy into a generic runtime callback. |
| [`7d06d5895c15`](https://github.com/torvalds/linux/commit/7d06d5895c159f64c46560dc258e553ad8670fe0), [`61f5acea8737`](https://github.com/torvalds/linux/commit/61f5acea8737d9b717fcc22bb6679924f3c82b98), [`1fdb92697469`](https://github.com/torvalds/linux/commit/1fdb926974695d3dbc05a429bafa266fdd16510e) | QCA reset handling moved away from resetting in open, which interfered with firmware loading, to core reset-resume handling; later narrowed to affected platforms. Relevant to the reset-resume table and the cost of broad quirks. |
| [`7ecacafc2406`](https://github.com/torvalds/linux/commit/7ecacafc240638148567742cca41aa7144b4fe1e) | Realtek runtime-PM regression history; another reason not to expand runtime reset support through a generic callback without testing. |
| [`811ae81320da`](https://github.com/torvalds/linux/commit/811ae81320da53a5670c36970cefacca8519f90e) | Explicit btusb runtime-rebind gap, discussed under T2. |
| [September 2026 Intel reset-resume proposal](https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05888.html) | A narrow callback for closed, fixed Intel adapters, with nonpersistent setup and explicit preservation of the quirk autosuspend restriction for other adapters. Not present in the reviewed base; latest disposition not established. |
| [Oliver Neukum's reply](https://lkml.iu.edu/hypermail/linux/kernel/2609.2/16641.html) | Asks about another device, S4, and connection state after data loss. Direct evidence of the review scope a new generic callback will face. |

I found no single historical statement that explains every vendor's absence of a btusb `reset_resume`. The history supports state restoration and rebind requirements; it does not justify treating every adapter alike. The September proposal's fallback `needs_binding` assignment is not itself a solution to T2's runtime scheduling gap.

### CO-44 and consumers

The original [`161510ccf91c`](https://github.com/torvalds/linux/commit/161510ccf91c) introduces the errno mapping during conversion of management operations to synchronous command work. I found no rationale in that commit for mapping timeout to authentication failure. Exact-title, commit-ID, and mailing-archive searches found the [November 2021 pull request](https://lists.openwall.net/netdev/2021/11/02/220), but did not recover an original review discussion explaining this mapping. That question remains open.

Later nearby changes include [`c0bb764fc082`](https://github.com/bluez/bluetooth-next/commit/c0bb764fc082672678d371c375597a6a9f614cf9) for cancellation and [`7eac80614300`](https://github.com/bluez/bluetooth-next/commit/7eac80614300563470cffabf4df2b63616787ee7) for rfkill errors. Both are already represented in the reviewed function. I did not locate another timeout-mapping fix in the searched commit history and indexed mailing-list results. This is not an exhaustive audit of unpublished branches or unindexed list traffic.

An [August 2022 Arch report](https://bbs.archlinux.org/viewtopic.php?pid=2054811) shows `0x0c24` command timeouts alongside Remove UUID authentication-failure messages. It supports the misleading-error symptom, not a proven attribution to the QCA runtime-resume defect.

Two external MGMT consumers were inspected. [python-btsocket's protocol decoder](https://github.com/ukBaz/python-btsocket/blob/main/btsocket/btmgmt_protocol.py), blob `32b2fb1ad04690931e3789a9788aeb280f568213`, exposes separate AuthenticationFailed and Timeout enum values. [Rust btmgmt's client](https://github.com/yskszk63/btmgmt/blob/84101deae9c20919e4c8d67b6d270fc67f19c0d7/src/client.rs#L409) checks success generically for Command Complete and forwards a typed status error for Command Status. Neither inspected path establishes dependence on the erroneous timeout-as-authentication mapping. Both show that a status change can be observable outside bluetoothd. Downstream application branching on those values was not exhaustively audited; no compatibility guarantee follows from this sample.

### Search scope and posting

Searches covered the target functions in kernel commit history, btusb reset-resume/firmware-loss history, exact CO-44 commit/title terms, runtime rebind and `needs_binding`, and public timeout/authentication-failure reports, using GitHub and indexed linux-usb/linux-bluetooth/LKML archives. No additional concrete pending fix was identified for `btusb_reset`, `btusb_waker`, `play_deferred`, or the deferred insertion race. The Intel callback series is relevant overlapping work. Search-index gaps and inaccessible lore pages limit negative results.

Use a plain-text question for T2 while the API/locking choice remains open. Use `[RFC PATCH]` for a concrete experimental diff and `[PATCH]` for the isolated ready fixes. Send one cross-subsystem thread to linux-usb with linux-bluetooth copied for core recovery design; copy the maintainers identified by the affected paths. Keep reproduction, base commit, actual observations, and the precise design question in the message. These are recommendations based on [kernel submission guidance](https://docs.kernel.org/process/submitting-patches.html) and MAINTAINERS, not a claimed special linux-usb rule requiring an RFC first. No messages were sent.

## T6 — Proposed commit wording

### A

```text
Bluetooth: btusb: Report failed runtime resume for deferred data

When a send is deferred while the device is suspended, btusb_waker()
requests a runtime resume. If that request fails, the worker returns
without reporting the error at that point. A later HCI command timeout
does not identify the failed resume request.

Report failures from usb_autopm_get_interface() in the waker. Suppress
-EACCES, which can occur while runtime PM is disabled, including during
system sleep transitions.
```

Replacement code comment:

```c
/* Runtime PM may be disabled, including during system sleep. */
```

This avoids claiming an absence of all PM-related logging, guarantees about draining, or hardware observation of the exact failed USB request. A is diagnostic; no stable nomination needed solely on the evidence here.

### E

```text
Bluetooth: btusb: Anchor deferred URBs while holding txlock

submit_or_queue_tx_urb() tests BTUSB_SUSPENDING under txlock but adds
the URB to the deferred anchor after releasing the lock. A successful
resume can drain the anchor and clear BTUSB_SUSPENDING in between.
The sender then adds its URB after the drain, and the scheduled waker
finds the device active without replaying it. An HCI command in that
URB can time out.

Add the URB to the anchor in the same critical section as the suspend
test. This serializes insertion with replay and clearing the flag.
The existing resume path already acquires the anchor lock under txlock.

Fixes: 7bee549e197c ("Bluetooth: Add USB autosuspend support to btusb driver")
```

Keep the successful-resume scope. Describe the project's forced-interleaving validation below `---`; do not claim that E repairs failed-resume cleanup by itself. E has a plausible stable case after the required validation because it prevents a reproduced command hang; make prerequisite relationships explicit for any later cleanup backport.

### CO-44

```text
Bluetooth: MGMT: Report command timeouts as MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED. A
synchronous HCI command that receives no response therefore reports
authentication failure to management clients, including for operations
that do not authenticate a peer.

For example, a Write Class of Device timeout during Remove UUID can
produce "Failed to remove UUID: Authentication Failed (0x05)" in
bluetoothd. Return MGMT_STATUS_TIMEOUT for -ETIMEDOUT so that the
management result describes the command failure.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
---
This changes the errno path's timeout result from MGMT 0x05 to 0x08.
It makes that path consistent with the HCI-status table's timeout
mapping, including HCI 0x08 (Connection Timeout) and 0x10 (Host
Timeout). A command receiving no answer reaches the errno path;
it is not a separate entry in the HCI-status table.

The accompanying BlueZ mgmt-tester case drops the controller response
to Write Class of Device and expects MGMT_STATUS_TIMEOUT. Other errno
mappings are unchanged.
```

I would omit `Cc: stable` from the initial posting and ask for the Bluetooth maintainer's backport judgment below the separator. The correction is small and justified, but changes an externally visible status, and the consumer survey is limited. Stable inclusion after upstream acceptance is still available. This is a conservative recommendation, not a claim that ABI-visible error corrections are prohibited by [stable rules](https://docs.kernel.org/process/stable-kernel-rules.html). Do not broaden the patch to `-EACCES`: distinct HCI statuses collapse to that errno, so a one-to-one reverse mapping is not available.

### C, if posted as RFC

```text
[RFC PATCH] Bluetooth: btusb: Block wake-enabled autosuspend for QCA9377 on Ryzen

A QCA9377 device with USB ID 13d3:3503 attached directly to a Ryzen
root hub stopped responding after runtime suspend and did not return
until the machine was power-cycled. The kernel attempted reset-resume
and eventually disconnected the device. The precise USB request that
failed was not captured on the laptop; the GET_STATUS failure path
was inferred from the source and reproduced with a device emulator.

Set BTUSB_WAKEUP_BROKEN for this USB ID on Ryzen when it is a direct
child of a root hub. This prevents runtime suspend while the interface
requires remote wakeup. It does not disable every runtime suspend.
```

Below `---`, state that the hardware evidence is one occurrence on one laptop and that the MediaTek similarity is a hypothesis. No Fixes tag or stable nomination is justified by that evidence alone. The generic Ryzen/USB-ID scope still needs corroboration or a narrower platform match.

## T7 — Emulator changes and acceptance tests

SET_CONFIGURATION is useful as a constrained proxy: the successful reset-and-verify path restores configuration, whereas an ordinary successful resume need not. It can be **faked** by explicit reconfiguration and **missed** when reset fails before configuration restoration. It also observes reset late: firmware state may already have been lost before the emulator sees that request. Keep the current proxy for the existing controlled scenario, but label it accurately and cross-check against kernel reset traces.

| Mode | Concrete design | Required observations |
|---|---|---|
| Delayed reset worker | Add a debug gate immediately before queued-reset work calls `usb_lock_device_for_reset()`. Release it only after the test observes runtime status `suspended`; log the lock-helper return. Do not sleep while holding the device or PM lock. | D can lose its reset without a PM pin. A corrected design either prevents autosuspend until recovery completes or resumes safely. Assert functional HCI recovery, not just a reset log. |
| Firmware/NVM lost on reset | Introduce `reset_generation`, `patch_loaded`, and `nvm_loaded`. Clear loaded state on a host-side reset notification, reset endpoint/event queues, expose accurate QCA status, and accept/track the actual firmware-download protocol. Reject ordinary HCI traffic until initialization finishes. | After reset, firmware download precedes ordinary traffic; a rebind runs setup; stale events do not leak into the new generation. SET_CONFIGURATION alone cannot fully validate early reset behavior. |
| BT-24 failure race | Gate a sender and a resume with debug completions; inject one synchronous failure in the first interrupt or first bulk submission/allocation that is actually checked by `btusb_resume()`. Arrange sender insertion after the old scuttle but before flag clear. | Baseline leaves a deferred URB; E plus failure-drain serialization does not. Avoid sleeping under `txlock`. An error returned later by the USB/IP server exercises completion, not this branch. |
| Ownership/leak | Run close with pending command and ACL URBs; separately fail resume and fail the first/middle deferred replay submission. Use kmemleak plus allocation/free counters keyed by URB/skb/setup packet. | Every never-submitted skb/setup/URB is released once, submitted URBs complete normally, no counter underflow. Exercise the first failed replay URB as well as the remaining queue. |

For kmemleak, enable its debug configuration, wait for deferred skb freeing and HCI teardown, drop retained request/sent-command references, and repeat scan after settling. Compare baseline and candidate with identical fault triggers. A clean scan alone is not proof: reachability, shared skb data, retained stack pointers, and allocator configuration can hide leaks. Use KASAN/lockdep alongside ownership counters to catch double frees and lock mistakes.

For a reset notification earlier than SET_CONFIGURATION, instrument the emulated host-controller/reset path or add an out-of-band reset-generation channel. A bus reset observed at host-controller level is a better trigger for firmware loss than a later device request.

For system-suspend testing without physical hardware, move device emulation outside the suspended guest: implement a QCA-like device in the VM's USB device model, with a real device-reset callback and configurable retained/lost firmware state. Alternatively implement the required gadget behavior in kernel context for a dummy-controller setup, then validate that controller's system-PM behavior. These are proposed harness extensions, not configurations I ran. An external USB/IP server alone does not remove vhci's attached-device suspend restriction. A userspace raw-gadget process inside the sleeping system remains subject to freezing; that limitation should not be stated as an impossibility for every possible gadget-based test.

## Recommended next steps

Proceed independently with A's corrected wording, E, and the one-line CO-44 change plus its test. Exercise the companion cleanup candidate with fault injection before splitting it for submission. Send the T2 design question with the 2021 precedent. Keep B and D out of a fix series until recovery generation, PM ordering, firmware restoration, and command cancellation are resolved. Preserve C as a narrowly described hardware hypothesis pending stronger platform evidence.

## The reviewer's covering comments

Reviewed all seven tasks against the specified kernel base and researched upstream history.
The main findings:

* T3’s leak is supported by the source, including the first URB rejected by `play_deferred()`. The candidate diff covers cleanup and includes E’s required insertion locking.
* T2 has direct precedent: commit `811ae81320da` describes btusb breaking because runtime reset-resume lacks subsequent rebinding.
* T4’s timer suppression is intentional: commit `7bdb8a5cf17f` prevents commands being sent before HCI Reset completes.
* B still needs coordinated recovery. Neither PM state nor a nonempty deferred anchor identifies whether the timed-out command reached the controller.
* A September 2026 Intel reset-resume proposal is relevant overlapping work; its review explicitly raises other devices, S4, and lost connection state. [lkml.iu.edu](https://lkml.iu.edu/hypermail/linux/kernel/2609.2/05888.html)

The report includes proposed commit messages, an unsent USB-list question, research limits, and concrete test designs.

* BT17-deferred-cleanup-candidate.diff

The diff passes applicability and available style checks. It has not been compiled or runtime-tested.
