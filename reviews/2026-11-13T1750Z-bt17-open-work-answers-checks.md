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
- **Unverified, being checked:** "2014-era Loic Poulain series" that scheduled a rebind after a
  runtime resume. Our CO-43 search was asked to find the messages. Until then it is not cited.
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

- **T5:** the 2014 claim is under check (above). "No evidence that the mapping was deliberate"
  agrees with our reading of `161510ccf91c`. The review thread is being searched.
- **T6:** no wording proposed, only agreement with the points listed.
- **T7:** agrees that the SET_CONFIGURATION signal is a sound proxy on vhci, and with the
  missing modes.
