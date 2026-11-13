# BT-17 open work — answers to the task document, and our checks

*2026-11-13. Answers to `2026-11-13T1740Z-bt17-open-work-for-outside-reviewers.md` are kept
verbatim beside this file (`2026-11-13T1740Z-bt17-open-work-answer-reviewer-<N>-verbatim.md`).
Each point was checked against bluetooth-next `da3cc0258` (the emulation worktree, and
`git show da3cc0258:<file>` copies in `tmp/bt17-review/r7-base/`). Reviewers 2, 3, 6 and 7 are
still working; their answers will be added here.*

## Reviewer 1

### T1, the sketch for B: a good direction, with two gaps that would fail its own requirement (b)

R1 proposes:
- `btusb_reset()` returns at once when `deferred` is non-empty (under `txlock`);
- otherwise it schedules a `reset_work` outside `hdev->workqueue`, which calls
  `usb_queue_reset_device()`. Taking `usb_autopm_get_interface()` there first is marked
  "optional".

1. **Taking the PM reference is not optional. Without it the reset is lost in exactly the
   `dropcmd-wedge` case.**
   - In that case the device is already autosuspended when the timeout fires: it suspended
     0.5 s after the send in every run.
   - `__usb_queue_reset_device()` (`drivers/usb/core/message.c:1962-1975`) resets only if
     `usb_lock_device_for_reset()` succeeds. That function returns `-EHOSTUNREACH` for a
     suspended device (`drivers/usb/core/usb.c:902-903`), and the work then drops the request
     silently.
   - This is the same flaw as D's (reviewer 7, our finding 14).
   - The existing `btusb_reset()` works because it first takes `usb_autopm_get_interface()`,
     which resumes the device, and keeps the reference (`BTUSB_RESET`) until the disconnect
     (`btusb_main.c:1101-1111`).
   - **So the work item must take the reference and keep it until the reset has run.** Doing
     that in a work item outside `hdev->workqueue` is what meets requirement (a): it may wait
     for the failing resume there without blocking HCI.
2. **"`deferred` is non-empty" does not mean "the timed-out command was deferred."**
   - ACL and ISO data take the same path. `submit_or_queue_tx_urb()` is used for
     `HCI_COMMAND_PKT`, `HCI_ACLDATA_PKT` and `HCI_ISODATA_PKT`
     (`btusb_main.c:2433-2466`, and again in the vendor `send_frame` variants at `:2903-2958`).
   - So a controller can swallow a sent command, autosuspend, and then have ACL data deferred
     before the timeout; the reset would then be skipped wrongly.
   - **A precise test records the command itself:** for example a flag set when an
     `HCI_COMMAND_PKT` URB is anchored on `deferred`, and cleared when `play_deferred()` sends
     it or the anchor is drained. Since the command credit is 1, at most one command is
     outstanding.
3. **Requirement (c), no double reset after a core reset-resume, is met only together with a
   BT-18 fix.** In the `recover` case the deferred command is never played: BT-18 leaves btusb
   unresumed. So skipping the reset leaves Bluetooth dead unless the core rebinds. R1 says the
   same in T2. The order stays: BT-18 first, then B.
4. **Lifetime.** The new work must be cancelled in `btusb_disconnect()` (`cancel_work_sync()`)
   before `btusb_data` is freed. The reset it queues then runs the unbind, and `btusb_disconnect()`
   is called from inside it. So the cancel must not wait on itself: a work item that only takes
   the reference and queues the reset, then returns, avoids that.
5. **Holds:**
   - the credit is restored as soon as `btusb_reset()` returns (`hci_cmd_timeout()`), so queued
     commands are not held;
   - in the BT-17 case each queued command then times out on its own (finding 2 of the
     earlier checks).

**Next:**
- write the variant: a work item, the PM reference kept until the reset, and a
  command-deferred flag;
- run it through `bt17`, `recover`, `close-recover`, `dropcmd`, `dropcmd-wedge` and `cycles`,
  on its own and on top of a BT-18 fix.

### T2, the BT-18 question

- **Holds:** the facts of the asymmetry. `rebind_marked_interfaces()` is called only from
  `usb_resume_complete()` (`driver.c:1655`) and through `usb_unbind_and_rebind_marked_interfaces()`
  from `usb_reset_device()` (`hub.c:6451`).
- **"2014-era Loic Poulain series" that scheduled a rebind after a runtime resume: verified.**
  Our CO-43 search found it (`contributions/CO-43-…/prior-art-2026-11-13.md` §2): "[PATCH] rebind:
  Add rebind mechanism for runtime-resume", linux-usb, 2014-03-10, and v3 and v4 up to
  2014-04-02.
  - Alan Stern on v1: *"Although the basic idea is okay, this patch has a couple of weak
    spots."*
  - No technical objection is on record against v3 or v4, and the series never landed.
  - What landed is `6aec044cc2f5` ("USB: unbind all interfaces before rebinding any",
    Reported-and-tested-by Loic Poulain), the helper his v3 calls.
  - (Our first reading in the session, that the claim garbled `6aec044cc2f5`, was wrong. It was
    never written into a file.)
- **Not specific enough to use:** "the runtime resume path may already hold the lock depending
  on the call chain". The constraint behind it is real: the USB core does not rebind inline
  from PM callbacks. But it needs a code reference before it goes into a mail.
- **The draft mail needs two corrections before use:**
  - **It mixes the laptop and the emulation.**
    - On the laptop, the reset-resume *failed* and the device left the bus.
    - "After the core's reset-resume the device answered USB requests but Bluetooth stayed
      dead" is the emulated `close-recover` case (`base-m-close-1`).

    The mail must say so.
  - **"a QCA9377 that did not answer GET_STATUS"** is inferred from timing and source, not
    logged (earlier checks, finding 20).
- **Otherwise:** short and factual, which is the right form. The preference for a core fix,
  with a real btusb `reset_resume` (vendor setup redone, HCI held, a PM reference held) as the
  interim, matches the plan.

### T3, BT-24 and BT-25: agrees

- R1 reads both from the source the same way.
- The proposed fix is ours as well: drain under `txlock` with `play_deferred()`'s cleanup plus
  `dev_kfree_skb_any()`, then clear the flag; complete the commands with an error if possible.
- Still to do: the emulator race and kmemleak tests (T7 c and d).

### T4, no recovery while an HCI Reset is pending

- R1 confirms the code reading.
- "Appears intentional (avoid recursive reset)" is R1's reading, not sourced. It stays a
  question for the Bluetooth maintainers, not a defect.

### T5 to T7

- **T5:** the 2014 claim is verified (above). "No evidence that the mapping was deliberate" agrees
  with our reading of `161510ccf91c`, and with its review thread (CO-44 prior art §1: nobody
  commented on the entry).
- **T6:** no wording proposed, only agreement with the points listed.
- **T7:** agrees that the SET_CONFIGURATION signal is a sound proxy on vhci, and with the
  missing modes.

## Reviewer 2

### T3, the deferred-URB leak (BT-25): agrees, and adds one path

- **Agrees from the source:** the two scuttles free neither the skb nor the setup packet.
- **Adds: `play_deferred()`'s submit-failure branch leaks the skb too.** It frees
  `setup_packet`, unanchors and frees the URB, and never frees `urb->context`
  (`btusb_main.c:4997-5005`). Checked; added to BT-25. So there are four sites:
  - the two scuttles;
  - `play_deferred()`'s failure branch;
  - `play_deferred()`'s cleanup loop.
- **R2's sketch:** a `btusb_discard_deferred()` helper under `txlock`, using
  `usb_get_from_anchor()`, `dev_kfree_skb_any()`, `kfree(setup_packet)` and `usb_free_urb()`.
  It is used at both scuttles and in `play_deferred()`.
  - The lock order matches `play_deferred()`'s: `txlock`, then the anchor's lock.
  - `setup_packet` is NULL for bulk URBs, and `kfree(NULL)` is a no-op.
  - Detaching the list under the lock and freeing it outside, as R2 suggests, is the
    production form.
- **Prior art that constrains the fix** (CO-43 prior art §4): "Bluetooth: btusb: Fix memory leak
  in play_deferred" (RFC v2, 2017) was not merged. Oliver Neukum, the author of btusb's PM code,
  objected: *"We cannot silently drop one part of a transmission."*
  - So the fix must report the dropped commands to the HCI layer, not only free them. R2 says the
    same: notify after releasing `txlock`.
  - The 2017 thread is to be read in full before our patch.
- **Ordering for BT-24:** R2 drains and clears the flag in one critical section, not "clear
  first", so that new URBs do not bypass the queue while RX failed to restart. That answers the
  open choice in BT-24's entry.

### T1, B's replacement: agrees on the direction, adds invariants

- **Agrees with our finding 2** on reviewer 1 (`deferred` holds ACL data), and adds that the
  timer gives btusb no identity of the timed-out command.
- **Invariants for any recovery mechanism:**
  - it survives disconnect and rebind;
  - it never touches freed `btusb_data`;
  - one recovery per failure, not one per timed-out command;
  - a successful core reset-resume and rebind invalidates stale requests;
  - the device is held active until the reset runs;
  - new HCI commands are held during recovery.
- **The `cancel_work_sync()` warning** applies to B2, now under test, which takes
  `usb_autopm_get_interface()` in a work item that `btusb_disconnect()` cancels synchronously.
  - The unpatched kernel already has the equivalent wait: `btusb_reset()` blocks on the HCI
    workqueue, which `hci_unregister_dev()` drains at the disconnect. In `base-bt17-2` the
    wait returned `-16` at the disconnect (+7.434 / +7.437) with no hang.
  - B2's `bt17` runs, with the hung-task detector and lockdep on, test exactly this.
  - Not assumed safe until they pass.
- **The credits:** R2 prefers holding new HCI commands during recovery over letting each time
  out. That is a design choice for the Bluetooth maintainers. B2 keeps today's behaviour, where
  the credit is restored and later commands time out on their own, and says so.

### T2, the linux-usb question

- `6aec044cc2f5` is verified (`cache/linux`): Alan Stern, 2014-03-12, all marked interfaces are
  unbound before any is rebound; Cc stable. Its relevance holds: btusb claims a second
  interface (isoc), so a rebind must be per device, through
  `usb_unbind_and_rebind_marked_interfaces()`, not per interface.
- R2's draft mail separates the code path from the emulated reproduction correctly. It also
  states the `close-recover` count (0 of 5 working, unpatched) correctly.
- **To add**, from the CO-43 prior art:
  - `9be427efc7644` (Johan Hovold, 2016, Acked-by Alan Stern): *"unlike system resume, run-time
    resume does not honour it"*;
  - the 2014 Poulain series;
  - `callbacks.rst`'s *"resume, reset_resume, or disconnect"*.
- **The recipients,** from precedent: To linux-usb with Alan Stern; Cc linux-bluetooth, the
  Bluetooth maintainers, Oliver Neukum and Johan Hovold. As a question, not an RFC.

### T4, no command timer during HCI Reset: the reason found

- **`7bdb8a5cf17f6`** (Szymon Janc, 2011-07-26), "Bluetooth: Don't use cmd_timer to timeout HCI
  reset command": *"No command should be send before Command Complete event for HCI reset is
  received."* It fixed a regression for chips whose reset takes long, such as CSR.
  - Found with `git log -S "test_bit(HCI_RESET, &hdev->flags)" v6.12 -- net/bluetooth/hci_core.c`
    in `cache/linux`.
- **So the intent was not to restore the command credit early** during a slow reset. It was not
  about recursion, as R1 guessed. Calling `hdev->reset` was never the point; `hci_cmd_timeout()`
  calls it today only as a side effect.
- **Any change must keep that property:** no command before the Reset completes. R2's proposal
  does: recover at a higher level, after the synchronous Reset has failed.
- **Unverified, not used:** R2's mention of "older HCI-core code" that documents avoiding
  recovery during initialization. It gives no commit or line.

### T6, wording

- **A:** R2's text is accurate. "Other code paths can report the PM error later" fixes the
  overclaim, and the `-EACCES` sentence is right.
  - Its new subject, "Report failed runtime PM wakeups for deferred TX", is clearer than ours.
- **E:** accurate and scoped, as asked.
- **CO-44:** accurate. Add the pairing-path sentence from the CO-44 prior art (a timed-out
  pairing connection already reports 0x08).
  - R2 recommends no `Cc: stable` at first. With the precedents on both sides (CO-44 prior art
    §5), it stays the operator's decision.
- **C:** accurate on what was and was not captured. Local only, as before.

### T7, the emulator

- **Reset signal:** to correlate the emulator's "reset seen" with the kernel's own
  `reset full-speed USB device` line in each run. That is cheap, and the harness will check
  both.
- **Mode 3, the BT-24 race,** needs a negative return from `usb_submit_urb()`, which an emulator
  behind vhci cannot produce for an already-accepted URB. It needs a debug-only fault injection
  in btusb, like the BT-23 delay. Agreed.
- **System suspend:** an in-kernel gadget function on `dummy_hcd` is not stopped by the freezer.
  The smaller first step R2 suggests is a minimal gadget and a minimal test driver without
  `reset_resume`, to test the core's rebind semantics. This matches the plan's open item.

## The CO-43 prior art (2026-11-13), for the plan

From `contributions/CO-43-…/prior-art-2026-11-13.md`:
- **D is against established intent.** btusb's missing `reset_resume` is deliberate:
  - Hans de Goede reverted one in 2013 (`b1a8014471b01`: re-enumerate instead);
  - Oliver Neukum (2014, 2017) and Marcel Holtmann (2015) rejected others;
  - Alan Stern and Oliver Neukum rejected the same idea for usblp in 2026-03.

  The Dell table relies on the autosuspend gate that D opens. So D stays local, as a fallback
  only.
- **BT-18 is a known gap upstream.** `9be427efc7644` names it, and the 2014 Poulain series
  (deferred rebind from `usb_runtime_resume()`) stalled without objection. The linux-usb question
  should be framed as that.
- **Nobody else is working on BT-18 to BT-24.** One pending, unmerged rewrite (Sean Rhodes,
  2026-08) touches the same code and keeps BT-23's window. E stays needed; rebase-check A and E
  against it if it moves.
- **`c93922dd316b7`** (2026-09, in our base) set `BTUSB_RESET` so the disconnect drops the
  reset's PM reference. B2 keeps that accounting. Its v4 notes say a first reset may fail, which
  agrees with finding 14 of the earlier checks.
- **Tests:** there is no upstream test framework for USB driver PM. Precedent describes emulation
  in a sentence or two in the body; none links an out-of-tree harness.

## Reviewer 6

R6 checked against mainline master, by function name; nothing was run.

### T1: one new fact, and a test that is weaker than R6 says

- **`hdev->reset` has a second caller: confirmed, and new to us.** `reset_store()`
  (`net/bluetooth/hci_sysfs.c:108-117` on `da3cc0258`) calls `hdev->reset(hdev)` from a write
  to the `reset` attribute.
  - So B refuses a manual reset of a suspended device too. And B2 as specified (a flag-based
    skip in `btusb_reset()`) would refuse it while a command is deferred.
  - **The skip belongs to the timeout path, not to every `hdev->reset` call.** An explicit user
    reset should always reset. `hdev->reset` has no caller argument, so the design must handle
    this, for example with a flag set around the call in `hci_cmd_timeout()`. That would touch
    `hci_core.c`, which is a maintainers' choice. To be added to the B2 design.
  - "Nothing ever resets it" in our `dropcmd-wedge` write-up therefore means nothing in the
    kernel; user space could, through this attribute. To be worded so.
- **R6's test, `BTUSB_SUSPENDING && !usb_anchor_empty(&data->deferred)`**, rests on "with one
  command credit, a non-empty `deferred` at the timeout holds the timed-out command". That does
  not hold:
  - a command can be sent and swallowed, the device can autosuspend (`tx_in_flight` 0), and
    ACL or ISO data can then be deferred before the timeout (reviewers 1 and 2; our check of
    R1, point 2);
  - so the flag recording a deferred `HCI_COMMAND_PKT` (B2) remains the precise test.
- **R6's raw-socket point applies to B2's flag as well.** A vendor command sent through a raw
  socket bypasses the credit, and if it is deferred it would set the flag although the
  timed-out command was sent. An edge case, to be stated in B2's message or excluded in the
  design.
- **R6's work item:** the same as B2's, with `cancel_work_sync()` after `hci_unregister_dev()`.
  - The table of cases is right, with the corrections above.
  - "(c) cannot be met inside btusb" agrees with our check of R1, point 3.
  - "Credit unchanged in practice, because the reset itself was always asynchronous" is right:
    `usb_queue_reset_device()` never waited.

### T2: confirmed; and a btusb fallback without D's side effects

- **Not inline, confirmed:** `usb_unbind_interface()` calls `usb_autoresume_device(udev)` near
  its start (`drivers/usb/core/driver.c:440-442`), so an unbind inside the runtime resume would
  wait on itself.
- **"every later resume skips it":** `usb_resume_interface()` jumps past the driver while
  `needs_binding` is set (`driver.c:1363`).
- **R6's fallback, `btusb_check_missed_resume()`, is new.** btusb keeps no `reset_resume`. After
  btusb itself has taken a PM reference (in the waker, open or close), it checks
  `intf->needs_binding`, or `BTUSB_SUSPENDING`. If set, it queues a reset, keeping the
  reference through `BTUSB_RESET`.
  - Against D, it opens no autosuspend gate, changes nothing at system resume, and cannot lose
    its reset.
  - It still pays a second reset, and catches a remote-wakeup resume only at the next TX.
  - **Worth prototyping as D2,** in place of D as the fallback: in emulation, `recover` and
    `close-recover`, plus `cycles`.
- **The mail draft:** the log lines are real (`base-m-close-1`, lines 581-618). But the excerpt
  leaves out the second interface's "no reset_resume" line (`btusb 2-1:1.1`), and must be copied
  verbatim with times when used.
  - The four questions are the right ones, and agree with the CO-43 prior art (one thread;
    `9be427efc7644` cited).
- **R6's warning from 2026-08** (Hongyu Xie's RFC, deferred unbind and rebind): Oliver Neukum
  objected to the system workqueue for work that allocates with `GFP_KERNEL`. A core fix needs
  a suitable queue. Taken into the question.

### T3: agrees; a better order for the fix

- **The leak:** agrees at all four sites. `urb_destroy()` frees the transfer buffer only with
  `URB_FREE_BUFFER`, which these URBs do not set.
- **R6 clears the flag under `txlock` first, then drains outside the lock in process context.**
  R2 drained and cleared in one critical section.
  - After E, a sender anchors on `deferred` only while the flag is set, under `txlock`. Once the
    flag is cleared under the lock, nothing can be added. So draining afterwards, outside the
    lock, is race-free.
  - It lets the free use `kfree_skb()` in process context instead of freeing under a spinlock
    with interrupts off.
  - R2's concern, that new URBs then bypass the queue while RX failed to restart, changes
    nothing in practice: on that path the device is unusable either way.
  - **R6's order is preferred.** It needs E first, as R6 says.
- **BT-24 "nearly moot"** (the submission fails only with `-ENODEV`, `-ESHUTDOWN` or `-ENOMEM`):
  fair as severity. The stranded URB then also leaks at close (BT-25). The combined fix covers
  both.
- **Error completion:** R6 is not sure it is worth it. The 2017 objection (*"We cannot silently
  drop one part of a transmission"*) argues for it. To be decided in the patch, with the 2017
  thread read.

### T4: agrees

- The exemption is intended (`7bdb8a5cf17f`, 2011, checked); the missing recovery is not.
- A fix belongs on the sync side. The risk of a reset loop at power-on, and the sysfs attribute
  as the user-space answer, are points for the maintainers.

### T6: wording

- **A:** clear. Its comment, `/* -EACCES: runtime PM is disabled, e.g. during system sleep */`,
  is the right size.
- **E:** accurate.
- **CO-44:** good. Its below-`---` note names `bt_status()` and the table, as the CO-44 prior art
  also recommends, and asks the maintainer whether the old value was deliberate.
  - "`Fixes:` alone usually gets it picked" for stable: true of the stable team's automatic
    selection. So the note should say what we intend, either way.
- **C:** the corrected sentence on what was and was not captured is right.

### T7

- **Reset signal:** the fakes R6 lists are real, but none occurs in our scenarios: no
  `usb_reset_configuration()`, and no usbfs or sysfs configuration write. Pairing the signal
  with the preceding device-descriptor read, and with the kernel's own `reset full-speed` line,
  is cheap, and will be done.
- **(d), a prediction for the kmemleak test:** an A+B `bt17` run should leak three skbs and three
  8-byte setup packets at the disconnect. Passed on to the kmemleak run.
- **System suspend:** run the emulator outside the guest, Raw Gadget on `dummy_hcd`, passed in
  with `-device usb-host` on QEMU's xHCI.
  - On this machine's own kernel that means loading `dummy_hcd` and `raw_gadget` on the host,
    which is the laptop, and needs the operator's word.
  - An outer VM, with nested QEMU, needs no such word. To be tried that way.

### Correction to the earlier checks, finding 7: accepted

`failed to resubmit (2)` appears on the unpatched kernel as well: `base-h-wedge-1` has it twice,
after btusb's own reset. So it belongs to the forced unbind after any reset, not to D. Finding 7
in `2026-11-13T1600Z-…-checks-and-plan.md` is corrected.
