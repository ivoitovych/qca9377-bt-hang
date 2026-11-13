# BT-17 patches — open work for outside reviewers, in parallel with ours (2026-11-13)

*Self-contained: every patch, the unpatched code it touches, our checks of seven earlier reviews,
the emulator, its source and its logs are below. Everything is on bluetooth-next
`da3cc02587c6` (2026-11-12), file `drivers/bluetooth/btusb_main.c`, unless a section says
otherwise. Nothing has been sent upstream.*

## 1. Where we are, in one page

**The incident (BT-17).** An idle QCA9377 USB Bluetooth controller (`13d3:3503`, AMD Ryzen
laptop) was runtime-suspended. The next HCI command started a resume that the device never
answered. The USB core's reset-resume failed, the device left the bus, and only a power cycle
brought it back. An emulated device under QEMU (usbip, the real btusb) reproduces the kernel's
side of this step by step. On the way, it found the defects below.

| id | defect | evidence | patch | state |
|---|---|---|---|---|
| BT-21 | `mgmt_errno_status()` reports a command timeout as `MGMT_STATUS_AUTH_FAILED` | laptop log; mgmt-tester case fails before and passes after | CO-44, one line, `Fixes: 161510ccf91c` | ready; five reviews agree |
| BT-23 | `submit_or_queue_tx_urb()` anchors on `deferred` outside `txlock`; a URB can miss the resume | source; emulation with a widened window | E, `Fixes: 7bee549e197c` (verified) | ready |
| BT-20 | `btusb_waker()` swallows a failed resume | source; emulation | A | ready after a rewording |
| BT-19 | `btusb_reset()` blocks the HCI workqueue behind a failing resume, and resets a reset-resumed device twice | laptop log; emulation | B | **wrong as written**: see task T1 |
| BT-18 | after a successful *runtime* reset-resume, btusb (no `reset_resume`) is never resumed or rebound: Bluetooth stays dead | emulation | D, a btusb-side `reset_resume` | **not as a fix**: see task T2 |
| BT-24 | `btusb_resume()`'s `failed:` path scuttles `deferred` outside `txlock` | source | none | see task T3 |
| (C) | QCA9377 on Ryzen: `BTUSB_WAKEUP_BROKEN`, as `dcaf83ead130` did for MT7922/MT7925 | one occurrence | C | RFC at most |

**New since the earlier reviews (all in section 4 below):**
- **B leaves Bluetooth dead in one case, shown in emulation.** A controller receives a command
  (the USB transfer completes), never answers it, and needs a USB reset to come back. The device
  autosuspends before the 2 s command timeout.
  - **Unpatched:** `btusb_reset()` resets it and Bluetooth works, 3 of 3.
  - **With B:** B skips the reset, 6 of 6, and nothing ever resets it again.
  - **Why nothing does:** the power cycle's HCI Resets fail with `-110`, and `hci_cmd_work()`
    does not arm the command timer while `HCI_RESET` is set (`hci_core.c:4351-4353`).
- **D's queued reset can be lost.** `usb_lock_device_for_reset()` refuses a suspended device,
  and D holds no PM reference. With the callback present, the core also stops setting
  `needs_binding` (reviewer 7, checked from the source).
- **`-EACCES` cannot be mapped to one MGMT status.** `bt_to_errno()` maps both HCI 0x05 and
  0x18 to it, and the HCI-status table maps them differently. CO-44 stays one line.

## 2. The tasks

Pick any. Each can be done from this document alone. The earlier findings are in section 4;
please don't redo them, unless you think one is wrong. Then say so.

### T1 — A correct replacement for patch B (BT-19)

Design a change to `btusb_reset()`, or to how `hci_cmd_timeout()` reaches it, that meets all
four requirements:
- **(a)** it does not block the ordered HCI workqueue behind a runtime resume that the device
  never answers (the BT-17 case: 5.3 s on the laptop);
- **(b)** it still resets a controller that **received** the timed-out command and needs a
  reset, even when the device autosuspended before the timeout (the `dropcmd-wedge` case, where
  B fails);
- **(c)** it does not reset a device twice when the core's reset-resume already reset it and the
  rebinding follows (the `recover` case);
- **(d)** it is not racy: `pm_runtime_active()` is a snapshot that can only be trusted under the
  PM lock, and it is true while runtime PM is disabled.

Questions:
- **The test.** Is "the timed-out command is still on `data->deferred`"
  (`!usb_anchor_empty(&data->deferred)` under `txlock`) the right one for "it never reached
  the controller"? Can a URB be in flight, neither deferred nor completed, while the device
  suspends?
- **The mechanism.** Should the reset be handed to a work item outside `hdev->workqueue`, which
  may then wait for the resume? Or should B use `pm_runtime_get_if_active()`? Or
  `usb_autopm_get_interface_async()`?
- **The credit.** `hci_cmd_timeout()` restores the command credit only after `hdev->reset()`
  returns. Does your design change when the queued commands are sent, and is that acceptable?
- **The cost.** In the BT-17 case each queued command then times out on its own, three
  `tx timeout` lines instead of one blocked one. Is that acceptable to the Bluetooth
  maintainers, in your reading?

Please answer with a sketch of the code, and the failure cases you checked it against.

### T2 — The BT-18 question for the USB maintainers

The USB core reset-resumes a device whose runtime resume failed (persist). btusb has no
`reset_resume`, so `usb_resume_interface()` sets `needs_binding`. But only a system resume
(`usb_resume_complete()` → `rebind_marked_interfaces()`) or `usb_reset_device()` acts on it, not
a runtime resume. btusb stays bound, never resumed, with `BTUSB_SUSPENDING` set.

Questions:
- **Intent.** Is this asymmetry intended, and why? `autosuspend_check()` refuses autosuspend for
  `USB_QUIRK_RESET_RESUME` devices whose driver lacks `reset_resume`. Is that gate the core's
  answer, which a reset-resume that persist forces after a *failed* runtime resume bypasses?
- **The fix.** What should the core do after a runtime reset-resume of an interface marked
  `needs_binding`? A deferred unbind and rebind (a work item, as `usb_queue_reset_device()`
  uses), failing the resume, or something else? What are the locking constraints in the runtime
  resume path that rule out doing it inline?
- **Or btusb.** Should btusb instead get a real `reset_resume`? It would re-run the vendor setup
  (firmware download for QCA ROME) with HCI traffic held until then, and hold a PM reference
  until the work is done. Reviewer 7 lists why patch D is not that.
- **The mail.** Please draft the question as it should go to linux-usb (and linux-bluetooth?).
  Keep it short, with the facts a maintainer needs and nothing about our process. The emulation
  log excerpt for `close-recover` (section 6) is the reproduction.

### T3 — BT-24, and a suspected leak on the same paths

- **BT-24.** `btusb_resume()`'s `failed:` path calls `usb_scuttle_anchored_urbs(&data->deferred)`
  without `txlock`, then clears `BTUSB_SUSPENDING` under it. A sender in between still sees the
  flag and anchors a URB that nothing sends. Is that right? Can it happen in practice: what makes
  the interrupt or bulk URB submission fail at resume?
- **A suspected leak, ours, from the source; not yet checked by test.** Is it right?
  - A deferred URB owns:
    - its skb (`urb->context`), freed only in `btusb_tx_complete()`;
    - for a command, its setup packet (`dr` in `alloc_ctrl_urb()`), freed in
      `btusb_tx_complete()` and in `play_deferred()`'s cleanup loop.
  - `usb_scuttle_anchored_urbs()` only unanchors and drops the anchor's reference (`urb.c`). So
    the two scuttles of `deferred`, in `btusb_close()` and in `btusb_resume()`'s `failed:`, appear
    to free neither the skb nor the setup packet.
  - `play_deferred()`'s cleanup loop frees the setup packet but not the skb.
- **The fix.** If both hold, propose one fix for both: drain `deferred` under `txlock` with the
  same cleanup as `play_deferred()`, plus the skb. Mind the context: `kfree_skb()` with interrupts
  disabled, so `dev_kfree_skb_any()`. And should the commands be completed with an error rather
  than dropped silently?

### T4 — No USB-level recovery while an HCI Reset is pending

`hci_cmd_work()` does not arm `cmd_timer` while `HCI_RESET` is set (`hci_core.c:4351-4353`).
So when a controller stops answering and the next command is an HCI Reset (power-on,
`hci_dev_open`), `hci_cmd_timeout()` and `hdev->reset()` are never called. The sync request
fails `-110`, and Bluetooth stays dead until the device is unplugged or the machine rebooted.
Even the unpatched kernel does not recover such a controller.

Questions:
- Is that intended? Why is the timer not armed for HCI Reset?
- Should a failed HCI Reset at power-on reach `hdev->reset` (the driver's recovery)?
- Is there a precedent or a discussion on linux-bluetooth?

This is a question, not a defect claim yet.

### T5 — Prior art and history (independent of our own search)

We are searching too. Independent results catch what one search misses.
- **CO-44:**
  - the review thread of `161510ccf91c` ("Bluetooth: hci_sync: Make use of
    hci_cmd_sync_queue set 1", 2021-10), and any reason given for `-ETIMEDOUT →
    MGMT_STATUS_AUTH_FAILED`;
  - later or pending patches to `mgmt_errno_status()`;
  - user reports of "Authentication Failed (0x05)" for power, mode, UUID or class operations;
  - MGMT socket users outside bluetoothd that branch on 0x05 or 0x08.
- **CO-43:**
  - why btusb has no `reset_resume`, and the intent of Realtek's `udev->reset_resume = 1`
    (rebind after a system resume) and of `btusb_needs_reset_resume_table`;
  - linux-usb discussions of rebinding after a runtime reset-resume;
  - reports of btusb devices dead after an autosuspend or runtime resume (QCA, others);
  - pending patches touching `btusb_reset`, `btusb_waker`, `play_deferred`,
    `submit_or_queue_tx_urb` or `BTUSB_SUSPENDING`.
- **Rules:** linux-usb's expectations for a question or RFC versus a patch, and for a question
  spanning two subsystems.

For each, give a URL or commit id. When nothing is found, say where and what you searched.

### T6 — Final wording

Propose the final commit message text for:
- **A:** the `-EACCES` comment must not claim system sleep only, nor that `btusb_resume()`
  always drains the data. The message's "nothing that said the resume had failed" overstates:
  there is `Failed usb_autopm_get_interface: -16` at the disconnect.
- **E:** its message, scoped to the successful-resume race; BT-24 is separate.
- **CO-44:** the message, and a short note below the `---`. The note says that the patch makes
  the errno path agree with the HCI-status table (0x08, 0x10 and no answer are all `TIMEOUT`
  there), and that the MGMT status of a timed-out command changes from 0x05 to 0x08.
  `Cc: stable` or not: give your reasoning.
- **C, if it is ever posted:** the GET_STATUS failure is inferred from the source and
  reproduced in emulation, not logged on the laptop. The subject "Disable runtime suspend"
  overstates what `BTUSB_WAKEUP_BROKEN` does.

Kernel style: plain, factual, no review history, no process.

### T7 — The emulator: what it can prove, and the tests still missing

The emulator and harness are in section 5, in full.
- **The reset signal.** `--wedge-until-reset` takes a SET_CONFIGURATION, seen while the
  emulator is wedged, as the sign of a USB reset. vhci handles the port reset and SET_ADDRESS
  itself, and a plain resume sends only GET_STATUS and CLEAR_FEATURE. Is that a sound signal?
  What could fake it, or hide it?
- **The missing modes.** Design, or better write, these modes:
  - **(a)** the reset work delayed past an autosuspend (D's lost reset);
  - **(b)** a reset that clears the controller's patch and NVM state, with `QCA_CHECK_STATUS`
    reporting not loaded, so that the rebind must download again (D's early traffic);
  - **(c)** a deferred send racing a failed interrupt or bulk URB submission at resume (BT-24);
  - **(d)** a kmemleak run for T3's suspected leak.
- **System suspend.** vhci refuses system suspend with a device attached, and a raw-gadget
  emulator cannot take part in a system resume. Is there any other way to test D's
  system-resume path, short of real hardware?

## 3. How to answer

- **Findings:** give each one a severity (blocker, should-fix, nit or question), a file and
  line on `da3cc0258`, and a short reason. Say whether it is from the source or from a run.
- **Code:** give it as a diff against `da3cc0258` or against the patch it replaces.
- **Uncertain points:** say "not sure" where you are. That is more useful to us than a
  confident guess.

## 4. What is settled: our checks of seven earlier reviews, and the emulation results
*(verbatim: `reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`)*
### BT-17 patches — outside reviews of the intermediate document (four, then a fifth): our checks, and the plan

*2026-11-13. The four answers to `2026-11-13T1100Z-bt17-patches-intermediate-review.md` are
kept verbatim beside this file:*
- *`2026-11-13T1600Z-bt17-patches-review-reviewer-1-verbatim.md`;*
- *`…-reviewer-2-verbatim.md`;*
- *`…-reviewer-3-verbatim.md`;*
- *`…-reviewer-6-verbatim.md`;*
- *reviewer 7, later: `2026-11-13T1700Z-bt17-patches-review-reviewer-7-verbatim.md`.*

*Reviewer 2's earlier assessment of the dossiers is
`2026-11-13T1530Z-bt17-patches-reviewer-2-verbatim.md`. Each claim below was checked against
bluetooth-next `da3cc0258` (`git show`/`git grep` in the emulation worktree) or against our own
emulation logs (`results/bt17-emulation-2026-11-13/logs/runs/`).*

#### Where the four agree

| item | R1 | R2 | R3 | R6 | R7 (later) | consensus |
|---|---|---|---|---|---|---|
| 1 (A) | nit, ready | nit | nearly ready | nit (wording) | nit (wording) | send alone after a wording fix |
| 2 (B) | should-fix | should-fix (B1 untested) | **blocker** | **blocker** | **blocker** | rewrite, after BT-18 is fixed |
| 3 (D) | should-fix | **blocker** | **blocker** | RFC to linux-usb only | **blocker** (the queued reset can be lost) | not as a fix; take BT-18 to the USB core |
| 4 (E) | ready | strong, one stress test | ready | ready (+ `Fixes:`) | ready, guarantee scoped to a successful resume | send alone |
| 5 (C) | RFC ok | RFC only | not as a fix | don't post | qualified RFC only | keep local; an A/B on the laptop at most |
| CO-44 kernel | ready, stable | nit, stable for the maintainers | add `-EACCES` | send, no `Cc: stable` | ready, `Fixes:` verified, stable after review | send, after the `-EACCES` question |
| CO-44 test | — | verify the hook fired | add an auth-failure test | send after the kernel patch lands | no blocker | refine, send second |

Reviewer 7's answer came after the other four
(`2026-11-13T1700Z-bt17-patches-review-reviewer-7-verbatim.md`). It is checked in its own section
below ("Reviewer 7, checked").

#### The new findings, checked

1. **B blocks recovery from an awake controller that swallows a command** (R2's B1, R6's
   blocker). **Plausible from the source; not yet tested.**
   - `HCI_CMD_TIMEOUT` is 2000 ms (`include/net/bluetooth/hci.h:486`), and the device's
     autosuspend delay is 2000 ms (`power/autosuspend_delay_ms` in every run).
   - btusb marks itself busy when it sends (`usb_mark_last_busy()` at `btusb_main.c:2381`), and
     `tx_in_flight` drops when the URB completes (`:2095`), not at the HCI answer.
   - So after a command the controller never answers, the autosuspend and the command timeout
     come due together. If the suspend wins, B sees `SUSPENDING` and an inactive interface and
     skips the reset of a controller that did get the command.
   - **Test to add:** an emulator mode that drops one HCI command while awake, run on base and on B.
2. **B's exception for a reset-resumed device never fires** (R6). **Confirmed in our own log.**
   - `ab-recover-1.log` (A+B, no D): the emulated device recovered at 12.36. The third class
     write at 13.16 still logged "Device not resumed; not resetting", and no "Resetting usb
     device." followed.
   - USB interfaces carry no runtime PM callbacks of their own. So the interface is active only
     while someone holds a usage count, and in the BT-18 state nobody does.
   - The run's `RESULT` line records only that hci0 still existed, not that it worked: the
     matrix had no A+B-only kernel judged on function. With B alone, the recovering device
     very likely stays dead (BT-18). Not yet shown by a command after the recovery.
3. **`pm_runtime_active()` is only a snapshot** (R1, R2, R3, R6). It is true while runtime PM is
   disabled, and an autosuspend that has started can still make `usb_autopm_get_interface()`
   wait.
   - Candidate replacements:
     - R3: `pm_runtime_get_if_active()`, which checks and takes the reference under the PM lock;
     - R6: `BTUSB_SUSPENDING && !usb_anchor_empty(&data->deferred)`, which tests what the commit
       message argues, namely that the command never left.
   - R3 and R6 both recommend fixing BT-18 first. B then needs no exception.
4. **B's commit message misdescribes the second reset** (R6). **Confirmed** (`base-m-recover-1.log`):
   - the reset-resume's reset at 11.645283;
   - btusb's `Resetting usb device.` at 11.781578;
   - the forced unbind at 11.781998;
   - a second reset at 11.932044;
   - the rebinding probe at 12.068371.

   So the rebinding comes from btusb's reset, not from the core. **With D the recovering device
   also gets two resets** (`final-m-recover-1.log`: 11.641932 and 11.933861). The CO-43 dossier's
   "no reset from btusb" is right about who resets, but the count is the same. D's real gain is
   the missing 5 s stall and recovery in the power-off case (`close-recover`), not one reset fewer.
5. **D opens a USB core gate** (R6). **Confirmed:** `autosuspend_check()` (`drivers/usb/core/driver.c:1963-1969`)
   refuses autosuspend to a `USB_QUIRK_RESET_RESUME` device whose interface driver has no
   `reset_resume`.
   - With D, such devices autosuspend whenever hci0 is closed, and every power-on then becomes
     a reset-resume, a second reset and a rebinding.
   - That covers the Dell entries that get the quirk from btusb's DMI table, and our own
     `usbcore.quirks=13d3:3503:b` test idea.
   - Neither the commit message nor the dossier said so.
6. **D replays traffic on a controller that was just reset** (R2's D2, R3). **Holds from the
   source.** `btusb_resume()` resubmits the interrupt and bulk URBs and plays the deferred ones
   before the queued reset unbinds btusb. The emulated controller is scripted to keep its state,
   so this was never exercised.
7. **D's `failed to resubmit (2)`** (R6). **Confirmed:** once per `final` recover and close run
   (`final-m-recover-1.log` line 653, 11.781107), right after the forced unbind: a URB killed by
   the unbind, `-ENOENT`. Harmless, but it is printed at error level.
8. **Is queueing the reset from the callback safe?** All four say yes, from the source:
   `usb_lock_device_for_reset()` refuses NOTATTACHED, UNBINDING and UNBOUND interfaces, and the
   work holds an interface reference.
9. **CO-44 lacks the `-EACCES` half** (R3). **Confirmed.**
   - `hci_sync.c:189` turns an HCI status into `-bt_to_errno(status)`, and `lib.c` maps HCI
     `0x05` to `EACCES`.
   - `mgmt_errno_status()` (`mgmt.c:284-311`) has no `-EACCES` case. So a sync command that the
     controller answers with Authentication Failure is reported as `MGMT_STATUS_FAILED` (0x03).
   - Adding `-EACCES → MGMT_STATUS_AUTH_FAILED` is consistent. Which MGMT commands can actually
     receive HCI `0x05` through the sync path is not yet traced.
   - **Traced afterwards (ours, `da3cc0258`): `-EACCES` is ambiguous, and `-ETIMEDOUT` is not.**
     - `__hci_cmd_sync_sk()` returns `-bt_to_errno(req_result)` when the controller answers
       (`hci_sync.c:189`), and `-ETIMEDOUT` when it does not (`:197`).
     - `bt_to_errno()` (`lib.c:63-152`) maps two HCI codes to `EACCES`, and `mgmt_status_table`
       (`mgmt.c:217-282`) treats them differently:

       | HCI code | name | errno | MGMT status from the table |
       |---|---|---|---|
       | `0x05` | Authentication Failure | `EACCES` | `AUTH_FAILED` |
       | `0x18` | Pairing Not Allowed | `EACCES` | `REJECTED` |

       So no single `-EACCES` case can match the table for both. `AUTH_FAILED` would be wrong
       for `0x18`.
     - `bt_to_errno()` maps three things to `ETIMEDOUT`, and the table gives `TIMEOUT` for each:

       | source | name | MGMT status from the table |
       |---|---|---|
       | HCI `0x08` | Connection Timeout | `TIMEOUT` |
       | HCI `0x10` | Connection Accept Timeout | `TIMEOUT` |
       | the sync wait itself | no answer | `TIMEOUT` |

       CO-44's one line makes the errno path agree with the table in every case. That is worth a
       sentence below the `---`.
     - Nothing else in `mgmt.c`, `hci_sync.c`, `hci_core.c` or `hci_conn.c` returns `-EACCES`
       (grep). So in this path `-EACCES` comes only from a controller's answer.
     - No MGMT sync command was found for which `0x05` or `0x18` is a documented Command
       Status or Complete result. The search was not exhaustive.
     - **Recommendation:** keep CO-44 to its one line, and leave `-EACCES` out. If it is ever
       wanted, the precise fix keeps the HCI status (for example `mgmt_status()` on
       `req_result`) instead of a lossy errno.
10. **Patch E's `Fixes:`** (R6: `7bee549e197c`). **Not checked:** the emulation tree is shallow
    and does not hold that commit. To check in a full-history tree before sending.
    - **Checked afterwards (`cache/linux`, full history): right.**
      - `7bee549e197c` is "Bluetooth: Add USB autosuspend support to btusb driver", Oliver
        Neukum, 2009-08-24.
      - Its `btusb_send_frame()` decides in `inc_tx()` under `txlock` and calls
        `usb_anchor_urb(urb, &data->deferred)` after the lock is dropped: BT-23's window,
        from the start.
      - The same commit added `btusb_waker()`'s silent return (BT-20, patch A) and the
        `failed:` path's scuttle outside `txlock` (BT-24).
11. **Smaller points that hold:**
    - A's "nothing said the resume had failed" overstates it: the unpatched log has
      `Failed usb_autopm_get_interface: -16`, at the disconnect (R6).
    - `-EACCES` is not only a system-sleep code: runtime PM can be disabled for other reasons
      (R2, R3).
    - The emulation README's title says "four btusb candidates"; there are five (R6).
    - The BlueZ test should check that the hook actually saw Write Class of Device (R2).
    - The BlueZ test must not land before the kernel patch, or the list's CI fails it (R6).
    - The laptop's first reset is attributed to the reset-resume from timing and source, not
      from a USB core trace (R2). The dossiers say so; keep it explicit.

#### Reviewer 7, checked

R7 read the sources at the same revisions (bluetooth-next `da3cc0258`, BlueZ `20ffd285b`) and the
harness at `0a17a7b`, and ran nothing. Each point was checked against `git show da3cc0258:<file>`
(extracted by `tmp/bt17-review/r7-base-files.sh`), our patches and our harness. **Every source
claim holds.** Line numbers are those of `da3cc0258`.

12. **B: the counterexample, made exact** (R7 §1; finding 1 above, now with its mechanism).
    **Confirmed from the source; not yet run.**
    - `btusb_tx_complete()` drops `tx_in_flight` when the USB transfer completes
      (`btusb_main.c:2094-2096`), not at the HCI answer.
    - `btusb_suspend()` refuses an autosuspend only while `tx_in_flight` is non-zero (`:4946-4951`).
    - So a command whose transfer completed but which the controller never answers leaves
      nothing that keeps the device awake. With an autosuspend delay shorter than the 2 s
      command timeout, the device is suspended when `btusb_reset()` runs, and B returns without
      a reset. There is no deferred URB and no waker.
    - B's message says "The command that timed out never reached the controller". That holds for
      BT-17, where the command was deferred, but not for every case B's test admits.
    - Our `--hold-hci` mode holds the USB transfer itself (`bt17-emu.py:265-267`: no
      `ret_submit`). So it keeps `tx_in_flight` up and cannot show this.
    - **Test to add:** complete the transfer, drop only the HCI event, and set
      `power/autosuspend_delay_ms` below 2000.
    - **Run (2026-11-13, `dropcmd`, delay 500 ms; `results/bt17-emulation-2026-11-13/logs/runs/*-h-dropcmd-*`):**
      - the device suspended about 0.5 s after the send, in all 9 runs;
      - unpatched: `Resetting usb device.`, 3/3;
      - A+B and the final series: `Device not resumed; not resetting`, 3/3 each;
      - Bluetooth worked afterwards in all 9.

      **So B's misclassification is confirmed.** Its harm is not shown yet: the emulated
      controller dropped one event and stayed healthy. Next: a controller that stays silent
      until a USB reset.
    - **The harm, shown (`dropcmd-wedge`; `*-h-wedge-*` logs).** Here the controller stays
      silent until it sees the re-enumeration after a USB reset:
      - unpatched: reset and usable, 3/3;
      - A+B and the final series: not reset and **dead**, 3/3 each, and also after a 60 s
        settle.
    - **Nothing else would reset it.** The power cycle's HCI Resets time out as
      `Opcode 0x0c03 failed: -110`. `hci_cmd_work()` does not arm the command timer while
      `HCI_RESET` is set (`hci_core.c:4351-4353`), so `btusb_reset()` is never called again.
    - **B is wrong as written; finding 12 is confirmed in full.**
13. **B's PM predicate** (R7 §2; finding 3). **Confirmed:** `pm_runtime_active()` is
    `runtime_status == RPM_ACTIVE || disable_depth` (`include/linux/pm_runtime.h:168-172`). Its
    comment says the result can be trusted only under the runtime PM lock or while the status
    cannot change. R7 adds:
    - `BTUSB_SUSPENDING` is cleared at the end of `btusb_resume()` (`:5067-5070`), while the
      device's resume may still be finishing;
    - so B's "does not block the HCI workqueue" is too strong. It avoids the wait that was
      observed, not every wait.
    - Any rewrite must tell a deferred command from one that was sent: R6's
      `!usb_anchor_empty(&data->deferred)` does that.
14. **D: the queued reset can be lost** (R7 §3). **New. Confirmed from the source; not yet run.**
    - The reset work, `__usb_queue_reset_device()` (`drivers/usb/core/message.c:1962-1975`),
      resets only if `usb_lock_device_for_reset()` succeeds. Otherwise it drops its interface
      reference: no retry and no message.
    - `usb_lock_device_for_reset()` (`drivers/usb/core/usb.c:895-925`) fails:
      - `-EHOSTUNREACH` if the device is suspended;
      - `-EBUSY` if the device lock is not free within one second;
      - `-EINTR` while the interface unbinds;
      - `-ENODEV` once the device is gone.
    - D queues the reset without holding a runtime PM reference (patch 3:
      `usb_queue_reset_device(intf)` after `btusb_resume()`). The existing `btusb_reset()`
      keeps the usage count it took until the disconnect (`btusb_main.c:1101-1111`).
    - So a device that autosuspends before the work runs is never reset, and btusb is never
      rebound.
    - D also stops the core's fallback. With a `reset_resume` callback,
      `usb_resume_interface()` calls it and no longer sets `needs_binding`
      (`drivers/usb/core/driver.c:1367-1375`). The system-resume rebinding is then gone as well.
    - **Test to add:** delay the reset work past the autosuspend.
    - **For D, if it is ever needed:** hold a PM reference until the reset has run, and define
      what happens when the lock is not obtained.
15. **D: return on a failed `btusb_resume()`? No** (R7 §4). **Confirmed:** `usb_resume_both()`
    ignores each interface's resume result (`driver.c:1580-1582`). So D's unconditional queueing
    is the only recovery after a failed resume. This answers the question from reviewer 2's
    earlier review ("say why the reset is queued even when `btusb_resume()` fails").
16. **D: traffic before recovery** (R7 §4; finding 6). The same as finding 6. R7 adds that our
    emulator cannot test it: it always reports patch and NVM loaded (`bt17-emu.py`,
    `QCA_CHECK_STATUS` → `0xc0`). The emulator needs a mode in which a reset clears the
    controller's state.
17. **A latent race on `btusb_resume()`'s failure path** (R7 §5). **New. Confirmed from the
    source; registered as BT-24.**
    - `failed:` calls `usb_scuttle_anchored_urbs(&data->deferred)` without `txlock`
      (`btusb_main.c:5075-5076`), then clears `BTUSB_SUSPENDING` under it (`:5078-5080`).
    - A sender that takes `txlock` in between still sees the flag and anchors its URB on
      `deferred`. With or without E, that URB is not sent until the next resume.
    - It predates our patches. E fixes the successful-resume race (BT-23), not this one.
    - E's message claims nothing about the failure path (checked), so E is unchanged.
    - **Test to add:** a deferred send that races a failed interrupt or bulk URB submission at
      resume.
18. **The harness does not judge recovery by function** (R7 §6). **All three points confirmed.**
    - **`--recover`:** the device becomes healthy when the host unlinks the held request
      (`bt17-emu.py:163-178`), not at a USB reset. The README's "a device that a reset brings
      back" was wrong and is corrected.
    - **`recover` scenario:** `scenario_bt17()` waits for `hci0` to reappear (`:480`), and its
      `RESULT` line leaves that value out (`:485`). The README's "5/5 hci0 back" means
      "reappeared", not "worked". Only `close-recover` and `sysfreeze` write the class after the
      recovery.
    - **Exit status:** a scenario's exception is logged and swallowed (`:653-654`).
      `run-guest.sh` ends with a `grep` (`:23`), and `run-matrix.sh` checks nothing.
    - The recorded traces stand: every matrix summary was read line by line. But the harness
      does not fail by itself.
    - **Fix before more runs:**
      - every recovery scenario ends with a power-on and an answered command, written into its
        `RESULT`;
      - a scenario that raises or fails exits non-zero, and the matrix counts it;
      - a recovery mode keyed to the USB reset, if vhci lets the emulator see one.
    - **Done 2026-11-13, except the reset-keyed mode:**
      - every scenario judges its own success, and the guest's verdict is `run-guest.sh`'s exit
        status;
      - `run-matrix.sh` counts failures;
      - `recover` now powers on and writes the class: `base-h-recover-1` and
        `final-h-recover-1` give `back=True powered=True class_write_after=0x00`.
19. **A's comment** (R7 §7; finding 11). **Holds.** A says "btusb_resume() sends the deferred data
    when it ends". On the failure path it scuttles them instead (`btusb_main.c:5075-5076`). The
    comment is to say that `-EACCES` can occur while runtime PM is disabled, as during a system
    sleep, and nothing more.
20. **C's wording** (R7 §7). **Holds, on two counts.**
    - C's message states as fact that the device "did not answer its GET_STATUS". The laptop's
      log has no GET_STATUS (emulation README, "not logged"). It is inferred from the source and
      reproduced in emulation, and the message must say so.
    - The subject "Disable runtime suspend" overstates it. `BTUSB_WAKEUP_BROKEN` acts only while
      the HCI device is open and needs remote wakeup. The message body already says so.
21. **CO-44** (R7 §8). **Agrees:** `Fixes: 161510ccf91c` is right.
    - R7 lists BlueZ code that treats `AUTH_FAILED` specially:
      - `bonding_attempt_complete()` (`src/adapter.c:8933`, PIN retry);
      - `device_bonding_complete()` (`src/device.c:7552`) and `:2092`;
      - the timeout case at `:3528`.
    - These are reached through pairing results. The kernel takes those from HCI status bytes
      (the positive-status table) or maps them explicitly (`pair_device()`, `mgmt.c:3772-3779`),
      so the patch leaves them as they are.
    - BT-21's audit line ("nothing in BlueZ depends on 0x05 for a timeout") stays true. It must
      not be read as "the two statuses are interchangeable".

#### The plan this gives (nothing sent; each send is the operator's)

1. **CO-44:**
   - decide on the `-EACCES` half: trace which commands get HCI `0x05` through the sync path,
     then add the case and a second mgmt-tester case if it is reachable;
   - put the user-visible status change below the `---`, and ask there whether the old
     mapping was deliberate;
   - send the kernel patch first and the BlueZ test after it lands. The test also checks
     that its hook fired.
2. **E alone:** check `Fixes: 7bee549e197c` in full history; add one stress run (concurrent TX,
   suspend, resume, disconnect).
3. **A alone:** reword the `-EACCES` comment ("expected while runtime PM is disabled, notably
   during system sleep") and the message's claim about earlier logging.
4. **BT-18 first, in the USB core:**
   - write up the runtime reset-resume asymmetry, reproduced in emulation, for linux-usb;
   - put the question there: should `usb_runtime_resume()` schedule the unbind and rebind, and
     deferred, not inline (R3)?
   - Patch D is kept as the btusb-side fallback, not sent as a fix.
5. **B afterwards:** rewrite it on top of the BT-18 fix, with no exception.
   - It must tell a deferred command from one that was sent (finding 13).
   - Test it in the emulator, judged by a command after the recovery:
     - against a command whose transfer completed and whose HCI answer is dropped, with an
       autosuspend delay under 2 s (finding 12);
     - against A+B alone (finding 2).
6. **C:** keep it local. If it is ever posted as an RFC, say that the GET_STATUS failure is
   inferred, not logged, and narrow the subject (finding 20).
7. **Doc fixes now:** the emulation README title, and the dossiers' statements on resets
   (finding 4).
8. **The harness before any further acceptance run** (finding 18):
   - functional `RESULT`s;
   - non-zero exits, counted by the matrix;
   - new modes:
     - drop the HCI event after a completed transfer (finding 12);
     - delay the reset work past the autosuspend (finding 14);
     - a reset that clears the controller's state (finding 16);
     - a deferred send racing a failed resume submission (finding 17).
9. **D, if BT-18 stays in btusb:** hold a PM reference until the queued reset has run, handle a
   failed lock, and keep HCI traffic quiet until the rebinding (findings 14 and 16).
*(verbatim: `results/bt17-emulation-2026-11-13/README.md`)*
### BT-17 in emulation: the kernel's side of the incident, reproduced, and five btusb candidates (2026-11-13)

Everything here ran in QEMU guests on the investigation machine. Nothing touched the laptop's
Bluetooth, and nothing was sent anywhere.

#### What it is

- **The kernel:** bluetooth-next `da3cc0258` (2026-11-12), with:
  - BlueZ's tester config plus SMP 4, KASAN, lockdep and dynamic debug;
  - usbip's virtual host controller;
  - `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y` (as on the laptop).
- **The device: real btusb against an emulated controller,** `harness/bt17-emu.py`, run
  inside the guest. It speaks usbip to `vhci_hcd`, so the kernel sees a USB device:
  - **Identity:** `13d3:3503`, bcdUSB 1.10, full speed, remote wakeup in bmAttributes, class
    e0/01/01, the laptop's endpoint layout. So btusb takes the `BTUSB_QCA_ROME` path:
    `btusb_setup_qca()`, `hdev->reset = btusb_qca_reset`.
  - **QCA vendor requests:** version ROM `0x302` / patch `0x3e8`; status `0xc0` (patch and NVM
    loaded), so no download.
  - **HCI:** answers the init sequence and every later command.
  - **Accounting:** counts device suspends (SET_FEATURE remote wakeup) and resumes (the next
    GET_STATUS).
- **The fault, `--fail-at N`:** at the N-th resume the device does not answer its GET_STATUS
  and holds every later request (a device that NAKs). When the host gives up (unlink), the
  device is "dead": every control transfer fails `-71`. With `--recover` it is healthy again
  instead. Strictly, it recovers when the host unlinks the held request, not at a USB reset
  (`Emu.unlink()`). So it models a device that answers again after the host's reset-resume, but
  cannot show that a reset is what brought it back.
- **The triggers:**
  - MGMT Set Device Class after the runtime autosuspend (`bt17`, the laptop's Write Class of
    Device at login);
  - MGMT Set Powered off (`close-recover`, btusb's close takes a PM reference);
  - a healthy loop (`cycles`).
- **Debug on:** USB core `hub.c` and `driver.c`, plus btusb's suspend, resume and disconnect,
  and the HCI command worker.

**What it can and cannot show:**
- **Can:** what the kernel does when a device stops answering after a runtime resume, on the
  same code path as the laptop's: the ROME reset hook, autosuspend, persist.
- **Cannot:**
  - why the QCA chip stopped answering;
  - what the AMD xHCI did. vhci handles port reset and SET_ADDRESS itself, so the xHCI
    errors of the laptop's tail (BT-22) do not appear here.

#### The reproduction (unpatched kernel)

`logs/runs/base-bt17-2.log`. Times are from the moment the command reached btusb (the
`cmd_cnt` line). The laptop's are from `results/incident-2026-11-12-1803/`.

| | laptop (18:03, monotonic) | emulation |
|---|---|---|
| command handed to btusb | 178.731 | 16.229 |
| `usb auto-resume` (who started it) | not logged | +0.001 |
| `finish resume` (GET_STATUS sent) | not logged | +0.061 |
| `command 0x0c24 tx timeout` | +2.041 | +2.051 |
| MGMT Set Device Class / Remove UUID status | 0x05 | 0x05 |
| `retry with reset-resume` | not logged | +5.260 |
| first `reset full-speed` | +5.291 | +5.384 |
| four resets, then `gone after usb resume?` | resets only | yes |
| `USB disconnect` | +7.352 | +7.434 |
| `Failed usb_autopm_get_interface: -16` | +7.352 | +7.437 |
| `Resetting usb device.` | never | never |
| btusb `intf` prints | 2 at suspend, none at resume, 2 at disconnect | the same |

So H1 and H2 (the outside reviews) hold on this code, for a host-initiated resume of a device
that stops answering:
- the first reset is the USB core's reset-resume after a 5 s GET_STATUS;
- btusb's reset waits behind it and never runs.

#### Defects found with it (registered in `docs/issues.md`)

- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed (no
  `reset_resume` callback; the core rebinds marked interfaces only after a system resume or a
  `usb_reset_device()`). Bluetooth stays dead with a healthy device. Reproduced by
  `close-recover` (unpatched: power-on fails, HCI Reset `-110` twice, MGMT 0x05).
- **BT-19:** `btusb_reset()` blocks the ordered HCI workqueue 5.4 s behind the failing resume.
  When the reset-resume succeeds, it then resets the device a second time
  (`Resetting usb device.` after the rebinding, `recover` scenario).
- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-21:** the MGMT 0x05 for a timeout (CO-44, tested separately with mgmt-tester).

#### The candidates (`patches/`, CO-43), in series order

1. **A**, "Bluetooth: btusb: Report a failed resume for deferred data" (BT-20).
2. **B**, "Bluetooth: btusb: Don't reset a device that has not resumed" (BT-19): no wait and
   no reset while `BTUSB_SUSPENDING` is set and the interface is not runtime-active.
3. **D**, "Bluetooth: btusb: Recover after a reset-resume" (BT-18): a `reset_resume`
   callback that resumes and queues a reset, so the core rebinds btusb.
4. **E**, "Bluetooth: btusb: Anchor a deferred URB under txlock" (BT-23).
5. **C**, RFC, "Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen"
   (H3): the `BTUSB_WAKEUP_BROKEN` condition of `dcaf83ead130` for this one device.

`patches/debug-only/` holds the delay used to widen BT-23's window; it is a test tool, not a
candidate.

checkpatch `--strict --no-tree`: each reports only the missing Signed-off-by (the operator
adds his own), plus for patch 5 the no-tree commit-id warning and two CamelCase notes on the
USB core's own field names.

#### Results

QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume. One guest per
run. Every log is in `logs/runs/` (named `<kernel>-<label>.log`, with `SHA256SUMS`); matrix
summaries are `logs/runs/matrix-*.txt`; each kernel's build record (commit, modified files,
key config) is `logs/bzImage-<kernel>.commit`.

| scenario | unpatched (`base`) | A+B+D (`abd`) | final series A,B,D,E,C (`final`) |
|---|---|---|---|
| dead device, resume started by a class write (`bt17`) | 5/5: the laptop's sequence; `hci_cmd_timeout()` blocked 5.4 s; `Failed usb_autopm_get_interface: -16` at the disconnect | 5/5: `Device not resumed; not resetting`, credit back at once; `Failed to resume device for deferred data: -16`; the core disconnects | 3/3 as A+B+D |
| device that answers again after the reset-resume, started by a class write (`recover`) | 5/5 hci0 back, through `btusb_reset()`'s second reset (`Resetting usb device.` in every run, BT-19) | 5/5 back through D's rebinding; no reset from btusb's timeout path, but still two USB resets, as unpatched: the reset-resume's and D's queued one (`final-m-recover-1`: 11.64 and 11.93; unpatched `base-m-recover-1`: 11.65 and 11.93, where btusb's reset causes the rebinding). The gain is no 5 s stall, not one reset fewer | 3/3 back |
| the same, started by powering hci0 off (`close-recover`) | **0/5**: Bluetooth dead afterwards (BT-18) | 5/5 works | 3/3 works |
| healthy suspend/resume cycles with a class write each | 50/50, median 0.062 s | 50/50, median 0.064 s | 50/50, median 0.063 s |
| dead device, guest with the host's CPU (Ryzen 7 5825U) | fails as above | — | the device no longer autosuspends with hci0 up (C); the fault never arises |
| the same with C, guest CPU not Zen (`abdc`) | — | — | as A+B+D (C does not apply) |
| BT-23, window widened to 400 ms by a debug-only delay, resume forced inside it (`bt23`) | 3/3: parked on an active device, timed out after 2.02 s, MGMT 0x05 | — | E: 2/2 answered after 0.40 s; 20/20 healthy cycles |
| system suspend (`pm_test=devices`, freeze) | not testable here. `vhci_hcd` refuses system suspend with a device attached (`platform_pm_suspend returns -16`), both kernels. A second emulator on Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`, `*-rg-*` logs, `SHA256SUMS-raw-gadget`) works before the sleep, but the freezer stops the user-space gadget during the resume ("device is not running") | | |

Kernel reports (`BUG:`, `WARNING:`, KASAN, lockdep, hung task) in any run: none.

**The hardened harness (2026-11-13, after the outside reviews; `*-h-*` logs, `SHA256SUMS-hardened`):**
- **What changed:**
  - every scenario now judges its own success;
  - the guest prints `BT17-EXIT 0|1`, and `run-guest.sh` exits with it (3 if the guest did not
    finish);
  - `run-matrix.sh` counts non-zero runs;
  - `bt17 --recover` now powers hci0 on and writes the class after hci0 reappears.
- **`recover`, rerun:** `base-h-recover-1` and `final-h-recover-1` both end
  `back=True powered=True class_write_after=0x00`.
- **New: `dropcmd`.** The emulated controller completes the USB transfer of one Write Class of
  Device and never sends its event. The autosuspend delay is 500 ms. The device suspended about
  0.5 s after the send in every run, before the 2 s command timeout:

  | kernel | `btusb_reset()` at the timeout | Bluetooth usable 15 s later |
  |---|---|---|
  | `base` | `Resetting usb device.`, 3/3 | 3/3 |
  | `ab` (A+B) | `Device not resumed; not resetting`, 3/3 | 3/3 |
  | `final` | `Device not resumed; not resetting`, 3/3 | 3/3 |

- **What `dropcmd` shows:**
  - **Shown:** B misclassifies a command that reached the controller and skips the reset, as
    the reviews predicted.
  - **Not shown:** that this matters. The emulated controller loses only that one event and
    answers the next command, so no recovery was needed.
  - **The deciding test:** a controller that stays silent until it is reset.
- **New: `dropcmd-wedge`, the deciding test.** The run is as `dropcmd`, but after the dropped
  command the emulated controller completes every HCI transfer and sends no events. It becomes
  healthy again only when it sees a SET_CONFIGURATION, which is the re-enumeration after a USB
  reset.
  - **Why that signal:**
    - vhci handles the port reset and SET_ADDRESS itself (`drivers/usb/usbip/vhci_hcd.c`), so
      the emulator never sees them;
    - a plain resume sends only GET_STATUS and CLEAR_FEATURE;
    - while the emulator was wedged, every control request was logged, and no plain resume sent
      a GET_DESCRIPTOR or SET_CONFIGURATION.
  - **The procedure:** after 15 s (60 s in the `settle60` runs), Set Powered off, Set Powered
    on, a class write.

  | kernel | `btusb_reset()` | reset seen | Bluetooth usable afterwards |
  |---|---|---|---|
  | `base` | `Resetting usb device.` | yes | **3/3** |
  | `ab` (A+B) | `Device not resumed; not resetting` | no | **0/3**, and 0/1 after 60 s |
  | `final` | `Device not resumed; not resetting` | no | **0/3**, and 0/1 after 60 s |

  - **On the B kernels, nothing ever resets the device:**
    - the power cycle's HCI Resets fail with `Opcode 0x0c03 failed: -110`, four times;
    - Set Powered on returns 0x05.
  - **Why:** `hci_cmd_work()` does not arm the command timer while an HCI Reset is pending
    (`net/bluetooth/hci_core.c:4351-4353`, `HCI_RESET`). So these failures never reach
    `hci_cmd_timeout()` or `btusb_reset()`, and the reset B skipped was the only one there
    would have been.
  - **So B, as written, leaves Bluetooth dead** when a controller that got a command needs a
    reset, and the device autosuspends before the command timeout. The unpatched kernel
    recovers it.

**How the results were judged** (outside review, reviewer 7):
- **`recover`:** "hci0 back" means that hci0 reappeared. That scenario does not power it on or
  send a command afterwards, and its `RESULT` line leaves the value out; it was read from the
  `hci0 back after recovery` line.
- **Functional checks:** only `close-recover` and `sysfreeze` write the class after the recovery.
- **Exit status:** the harness does not fail by itself. A scenario's exception is logged and
  swallowed, `run-guest.sh` ends with a `grep`, and `run-matrix.sh` checks nothing.
- **Every count above** was read from the logs by hand.
- **Before any further acceptance run**, the harness gets functional `RESULT`s and non-zero exits
  (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`, finding 18).

**The laptop tool `scripts/bt17-provoke.py`, run unchanged in a guest:**
- healthy device: 18 cycles, 18 answered;
- device failing at resume 4: "FAILURE at cycle 4", with the device's runtime status
  `resuming` in its record.

Its first version had a 14-byte HCI filter, which the kernel refuses (EINVAL; `struct
hci_ufilter` is 16 bytes with padding). The emulator caught it; fixed before any laptop use.

#### Rerunning

- `harness/build-guest-kernel.sh <tag>` builds from a bluetooth-next worktree.
- `harness/run-guest.sh <tag> <label> <scenario> [--fail-at N] [--recover]` runs one guest;
  `harness/run-guest-hostcpu.sh` passes `-cpu host`, so the guest sees the Ryzen.
- `harness/run-matrix.sh <tag> <first> <last>` runs the repeat matrix.

Paths in the scripts are those of the work directory `/root/exp/agent-work/bt17-emu-20261113/`.
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-abd-1-5.txt`
```
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Device not resumed; not resetting
abd dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 1:   10.680 [mono  13.451170] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 1: [32m[    8.268068] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   10.284033] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   12.331694] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 1: [32m[   13.391644] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 1: [32m[   13.392040] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 1: Bluetooth: hci0: Device not resumed; not resetting
abd recover 1: Bluetooth: hci0: Device not resumed; not resetting
abd recover 1:    9.393 [mono  12.132162] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 1: [32m[    8.230243] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 1: [32m[   10.246233] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 1:   10.144 [mono  12.880485] RESULT close-recover bluetooth_works_after=True
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Device not resumed; not resetting
abd dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 2:   10.724 [mono  13.457241] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 2: [32m[    8.226039] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   10.273426] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   12.289306] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 2: [32m[   13.385454] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 2: [32m[   13.385807] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 2:  Device not resumed; not resetting
abd recover 2: Bluetooth: hci0: Device not resumed; not resetting
abd recover 2:    9.319 [mono  12.098821] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 2: [32m[    8.289223] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 2: [32m[   10.335517] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 2:   10.127 [mono  12.870739] RESULT close-recover bluetooth_works_after=True
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Device not resumed; not resetting
abd dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 3:   10.740 [mono  13.475695] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 3: [32m[    8.224842] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   10.240571] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   12.257141] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 3: [32m[   13.392736] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 3: [32m[   13.393238] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 3: Bluetooth: hci0: Device not resumed; not resetting
abd recover 3: Bluetooth: hci0: Device not resumed; not resetting
abd recover 3:    9.370 [mono  12.117332] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 3: [32m[    8.259522] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 3: [32m[   10.275276] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 3:   10.124 [mono  12.872791] RESULT close-recover bluetooth_works_after=True
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Device not resumed; not resetting
abd dead 4: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 4: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 4:   10.452 [mono  13.169441] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 4: [32m[    8.224536] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   10.272676] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   12.320674] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 4: [32m[   13.124229] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 4: [32m[   13.124646] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 4: Bluetooth: hci0: Device not resumed; not resetting
abd recover 4: Bluetooth: hci0: Device not resumed; not resetting
abd recover 4:    9.388 [mono  12.103978] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 4: [32m[    8.225743] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 4: [32m[   10.241584] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 4:   10.084 [mono  12.848380] RESULT close-recover bluetooth_works_after=True
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Device not resumed; not resetting
abd dead 5: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 5: Bluetooth: hci0: Failed to resume device for deferred data: -16
abd dead 5:   10.756 [mono  13.509776] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
abd dead 5: [32m[    8.263813] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   10.311638] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   12.359760] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd dead 5: [32m[   13.468192] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd dead 5: [32m[   13.468637] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
abd recover 5: Bluetooth: hci0: Device not resumed; not resetting
abd recover 5: Bluetooth: hci0: Device not resumed; not resetting
abd recover 5:    9.357 [mono  12.106603] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
abd recover 5: [32m[    8.259680] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd recover 5: [32m[   10.307516] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
abd close 5:   10.139 [mono  12.862753] RESULT close-recover bluetooth_works_after=True
abd cycles50:  108.521 [mono 111.272644] class write latency after a suspend: n=50 min 0.058 median 0.064 max 0.131 s
abd cycles50:  108.521 [mono 111.272949] RESULT cycles n=50 failures=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-base-1-5.txt`
```
base dead 1: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 1:   10.793 [mono  13.532697] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 1: [32m[   13.450911] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 1: Bluetooth: hci0: Resetting usb device.
base recover 1:    9.381 [mono  12.111181] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 1: [32m[   11.781578] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 1:   16.682 [mono  19.435717] RESULT close-recover bluetooth_works_after=False
base dead 2: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 2:   10.708 [mono  13.452755] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 2: [32m[   13.378368] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 2: Bluetooth: hci0: Resetting usb device.
base recover 2:    9.344 [mono  12.116315] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 2: [32m[   11.783104] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 2:   16.721 [mono  19.497472] RESULT close-recover bluetooth_works_after=False
base dead 3: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 3:   10.683 [mono  13.471819] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 3: [32m[   13.392676] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 3: Bluetooth: hci0: Resetting usb device.
base recover 3:    9.397 [mono  12.107285] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 3: [32m[   11.779949] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 3:   16.729 [mono  19.500630] RESULT close-recover bluetooth_works_after=False
base dead 4: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 4:   10.739 [mono  13.473863] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 4: [32m[   13.420752] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 4: Bluetooth: hci0: Resetting usb device.
base recover 4:    9.378 [mono  12.131390] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 4: [32m[   11.797465] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 4:   16.665 [mono  19.438284] RESULT close-recover bluetooth_works_after=False
base dead 5: Bluetooth: hci0: Failed usb_autopm_get_interface: -16
base dead 5:   10.670 [mono  13.441795] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
base dead 5: [32m[   13.381475] [0m[33mBluetooth: [0m[31mhci0: Failed usb_autopm_get_interface: -16[0m
base recover 5: Bluetooth: hci0: Resetting usb device.
base recover 5:    9.387 [mono  12.113944] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
base recover 5: [32m[   11.787573] [0m[33mBluetooth: [0m[31mhci0: Resetting usb device.[0m
base close 5:   16.680 [mono  19.441516] RESULT close-recover bluetooth_works_after=False
base cycles50:  108.327 [mono 111.040649] class write latency after a suspend: n=50 min 0.060 median 0.062 max 0.098 s
base cycles50:  108.328 [mono 111.041716] RESULT cycles n=50 failures=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-dropcmd-batch.txt`
```
base h-dropcmd-2 exit=0
base h-dropcmd-3 exit=0
ab h-dropcmd-1 exit=0
ab h-dropcmd-2 exit=0
ab h-dropcmd-3 exit=0
final h-dropcmd-1 exit=0
final h-dropcmd-2 exit=0
final h-dropcmd-3 exit=0
final h-recover-1 exit=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-final-1-3.txt`
```
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Device not resumed; not resetting
final dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 1: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 1:   10.754 [mono  13.505078] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 1: [32m[    8.270395] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   10.289035] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   12.302244] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 1: [32m[   13.466586] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 1: [32m[   13.467026] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 1: Bluetooth: hci0: Device not resumed; not resetting
final recover 1: Bluetooth: hci0: Device not resumed; not resetting
final recover 1:    9.355 [mono  12.108769] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 1: [32m[    8.257959] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 1: [32m[   10.273934] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 1:   10.113 [mono  12.893444] RESULT close-recover bluetooth_works_after=True
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Device not resumed; not resetting
final dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 2: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 2:   10.434 [mono  13.129775] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 2: [32m[    8.185901] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   10.222942] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   12.227746] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 2: [32m[   13.055706] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 2: [32m[   13.056331] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 2: Bluetooth: hci0: Device not resumed; not resetting
final recover 2: Bluetooth: hci0: Device not resumed; not resetting
final recover 2:    9.128 [mono  11.849867] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 2: [32m[    8.237191] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 2: [32m[   10.253315] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 2:   10.130 [mono  12.853797] RESULT close-recover bluetooth_works_after=True
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Device not resumed; not resetting
final dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 3: Bluetooth: hci0: Failed to resume device for deferred data: -16
final dead 3:   10.496 [mono  13.200593] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
final dead 3: [32m[    8.198334] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   10.246461] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   12.262159] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final dead 3: [32m[   13.150988] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final dead 3: [32m[   13.151402] [0m[33mBluetooth: [0m[31mhci0: Failed to resume device for deferred data: -16[0m
final recover 3: Bluetooth: hci0: Device not resumed; not resetting
final recover 3: Bluetooth: hci0: Device not resumed; not resetting
final recover 3:    9.356 [mono  12.132998] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True
final recover 3: [32m[    8.278902] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final recover 3: [32m[   10.326222] [0m[33mBluetooth: [0m[31mhci0: Device not resumed; not resetting[0m
final close 3:   10.132 [mono  12.873336] RESULT close-recover bluetooth_works_after=True
final cycles50:  106.315 [mono 109.071103] class write latency after a suspend: n=50 min 0.060 median 0.063 max 0.068 s
final cycles50:  106.316 [mono 109.071581] RESULT cycles n=50 failures=0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/matrix-wedge-batch.txt`
```
base h-wedge-2 exit=0
base h-wedge-3 exit=0
ab h-wedge-1 exit=1
ab h-wedge-2 exit=1
ab h-wedge-3 exit=1
final h-wedge-1 exit=1
final h-wedge-2 exit=1
final h-wedge-3 exit=1
done
```

## 5. The emulator and harness source, in full
#### `results/bt17-emulation-2026-11-13/harness/PLAN.md`
```markdown
# BT-17 emulation and patch candidates (2026-11-13, operator away about 4 h)

Everything runs in QEMU guests; nothing touches the laptop's Bluetooth; nothing is sent.

1. Reproducer: real btusb (bluetooth-next da3cc0258) in a guest, bound through usbip to
   scripts/bt17-emu.py, an emulated 13d3:3503 (QCA ROME path, full speed, bcdUSB 1.10,
   remote wakeup). Fault: at resume N the device holds GET_STATUS (a NAKing device); after
   the host gives up, every control transfer fails -71 (as the laptop after its first reset).
   Trigger: MGMT Set Device Class after the device autosuspended (the laptop's Write Class
   of Device). USB core dyndbg on, which the laptop lacked.
2. Baselines: healthy suspend/resume cycles; a recoverable device (works again after reset).
3. Patch candidates (bluetooth-next), each run against the reproducer and the baselines:
   a. btusb: btusb_waker() reports a failed autoresume (today silent);
   b. btusb: btusb_reset() does not block the ordered HCI workqueue behind a resume;
   c. btusb: 13d3:3503 on a Ryzen root hub sets BTUSB_WAKEUP_BROKEN (mitigation, H3);
   d. MGMT: -ETIMEDOUT -> MGMT_STATUS_TIMEOUT (a separate worker, bt17-mgmt-timeout/).
4. A provoking script for the laptop (reviewer 6's step 6), written, not run.
5. Registers: issues.md / STATUS rows for the new defects, a CO dossier; commit and push.
```
#### `results/bt17-emulation-2026-11-13/harness/bt17-emu.py`
```python
#!/usr/bin/env python3
"""bt17-emu.py - an emulated QCA9377 Bluetooth controller (13d3:3503) for the BT-17 incident,
attached through the kernel's usbip vhci_hcd so that the real btusb binds to it in a QEMU guest.

Derived from results/laptop-only-work-2026-11-11/.../usbip-bt-emu.py (CO-21). What is new:
  * the laptop's identity: 13d3:3503, bcdUSB 1.10, full speed, remote wakeup in
    bmAttributes, so btusb takes the BTUSB_QCA_ROME path (hdev->reset = btusb_qca_reset);
  * the two QCA vendor requests of btusb_setup_qca(): QCA_GET_TARGET_VERSION answers
    ROM 0x302 / patch 0x3e8, QCA_CHECK_STATUS answers 0xc0 (patch and NVM already loaded),
    so no firmware download is attempted;
  * suspend/resume accounting: a SET_FEATURE(DEVICE_REMOTE_WAKEUP) marks a device suspend,
    the next device GET_STATUS marks the resume check (finish_port_resume());
  * a fault, --fail-at N: at the N-th resume the device stops answering. Its GET_STATUS and
    every later request are held (a device that NAKs). When the host gives up on a held URB
    (unlink), the device turns 'dead': every control transfer then fails with -71 (EPROTO),
    as the laptop's controller did after its first reset. --recover makes it healthy again
    instead (a device that a reset brings back);
  * a driver for the incident: MGMT Set Powered, wait for the runtime autosuspend, then
    MGMT Set Device Class (the kernel writes the Class of Device, as at the laptop's login),
    MGMT events logged with their status, the kernel log and the USB core debug lines
    collected at the end.
It emulates the device only: nothing here is measured on the laptop.

Usage: bt17-emu.py <scenario> [--fail-at N] [--recover] [--cycles N] [--hold-hci]
       [--drop-hci-event OPCODE] [--autosuspend-ms N]   (dropcmd)
Exit status: 0 if the scenario's success condition held, 1 if not or if it raised.
Scenarios: bt17 (fault at a resume, then the class write), cycles (healthy suspend/resume
cycles with a class write each), up (bring-up only).
"""
import ctypes
import os
import socket
import struct
import sys
import threading
import time
from collections import deque

T0 = time.time()
LOG_LOCK = threading.Lock()


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOG_LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def arg(name, default=None):
    if name in sys.argv:
        i = sys.argv.index(name)
        return sys.argv[i + 1]
    return default


# ---------------------------------------------------------------- descriptors
def ep(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + ep(0x81, 3, 16, 1) + ep(0x82, 2, 64, 0) + ep(0x02, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + ep(0x83, 1, mps, 1) + ep(0x03, 1, mps, 1)
    total = 9 + len(body)
    # bmAttributes 0xe0: self-powered and remote wakeup, as the laptop's controller
    return struct.pack("<BBHBBBBB", 9, 2, total, 2, 1, 0, 0xE0, 50) + body


# bcdUSB 1.10, class e0/01/01, ep0 64, 13d3:3503, bcdDevice 0.01
DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)

# struct qca_version: rom_version, patch_version, ram_version, chip_id, platform_id, flag, rsvd
QCA_VERSION = struct.pack("<IIIBBH4s", 0x00000302, 0x000003E8, 0x00000302, 0, 0, 0, b"\0" * 4)

BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x00])
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])


class Emu:
    def __init__(self, fail_at=0, recover=False, hold_hci=False):
        self.lock = threading.Lock()
        self.intr_pending = deque()
        self.intr_out = bytearray()
        self.unknown = set()
        self.sock = None
        self.running = True
        self.fail_at = fail_at
        self.recover = recover
        self.hold_hci = hold_hci
        self.drop_op = None              # --drop-hci-event: opcode armed once, by the scenario
        self.wedge_until_reset = "--wedge-until-reset" in sys.argv
        self.hci_wedged = False          # after the drop: transfers complete, no events
        self.reset_seen = []             # mono times of the reset signal
        self.state = "healthy"          # healthy | wedged | dead
        self.suspended = False
        self.suspends = 0
        self.resumes = 0
        self.held = {}                   # seq -> description
        self.events = []                 # (mono, what)
        self.hci_cmds = []               # (mono, opcode)

    def note(self, what):
        self.events.append((mono(), what))
        log("EMU " + what)

    # -- usbip
    def attach(self):
        base = "/sys/devices/platform/vhci_hcd.0"
        kfd, self.sock = socket.socketpair()
        with open(base + "/attach", "w") as f:
            f.write("0 %d %d 2" % (kfd.fileno(), (1 << 16) | 2))   # full speed
        log("attached to vhci_hcd port 0")
        self.kfd = kfd
        threading.Thread(target=self.loop, daemon=True).start()

    def recvn(self, n):
        b = b""
        while len(b) < n:
            c = self.sock.recv(n - len(b))
            if not c:
                raise EOFError
            b += c
        return b

    def send(self, data):
        with self.lock:
            self.sock.sendall(data)

    def ret_submit(self, seq, status=0, actual=0, data=b""):
        h = struct.pack(">IIIII", 3, seq, 0, 0, 0)
        h += struct.pack(">iiiii", status, actual, 0, 0, 0)
        h += b"\0" * 8
        self.send(h + data)

    def ret_unlink(self, seq, status):
        self.send(struct.pack(">IIIII", 4, seq, 0, 0, 0) + struct.pack(">i", status) + b"\0" * 24)

    def loop(self):
        try:
            while self.running:
                hdr = self.recvn(48)
                cmd, seq, devid, direction, epn = struct.unpack(">IIIII", hdr[:20])
                u = hdr[20:]
                if cmd == 1:
                    flags, buflen, start, nump, ival = struct.unpack(">IiiiI", u[:20])
                    setup = u[20:28]
                    data = b""
                    if direction == 0 and buflen > 0:
                        data = self.recvn(buflen)
                    if nump > 0:
                        self.recvn(16 * nump)
                    self.submit(seq, direction, epn, buflen, setup, data)
                elif cmd == 2:
                    self.unlink(seq, struct.unpack(">I", u[:4])[0])
                else:
                    log("unknown usbip command %d" % cmd)
        except (EOFError, OSError) as e:
            log("usbip socket ended: %r" % (e,))

    def unlink(self, seq, victim):
        hit = False
        with self.lock:
            for item in list(self.intr_pending):
                if item[0] == victim:
                    self.intr_pending.remove(item)
                    hit = True
        if victim in self.held:
            what = self.held.pop(victim)
            hit = True
            self.note("host gave up on held %s (unlink)" % what)
            if self.state == "wedged":
                if self.recover:
                    self.state = "healthy"
                    self.note("device recovers (--recover)")
                else:
                    self.state = "dead"
                    self.note("device dead: control transfers now fail -71")
        self.ret_unlink(seq, -104 if hit else 0)

    def submit(self, seq, direction, epn, buflen, setup, data):
        if epn == 0:
            self.control(seq, direction, buflen, setup, data)
        elif epn == 1 and direction == 1:
            with self.lock:
                self.intr_pending.append((seq, buflen))
            self.pump()
        elif epn == 2 and direction == 1:
            pass                                    # bulk IN: kept pending
        elif epn == 2 and direction == 0:
            if self.state == "healthy":
                self.ret_submit(seq, 0, buflen)
            elif self.state == "dead":
                self.ret_submit(seq, -71, 0)
            else:
                self.held[seq] = "bulk OUT"
        elif epn == 3:
            self.ret_submit(seq, -71 if self.state != "healthy" else 0, 0)
        else:
            self.ret_submit(seq, -32, 0)

    def control(self, seq, direction, buflen, setup, data):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        desc = "control %02x %02x %04x %04x %04x" % (bm, br, wv, wi, wl)
        if self.hci_wedged:
            # reset signal: SET_CONFIGURATION (usb_reset_and_verify_device() sends it to restore
            # the configuration after every reset; vhci_hcd handles the port reset and
            # SET_ADDRESS itself and never forwards them)
            self.note("ctl while wedged: " + desc)
            if bm == 0x00 and br == 9:
                self.hci_wedged = False
                self.intr_out.clear()
                self.reset_seen.append(mono())
                self.note("reset seen (SET_CONFIGURATION value %d)" % wv)
        if self.state == "dead":
            self.note("%s -> -71 (dead)" % desc)
            self.ret_submit(seq, -71, 0)
            return
        if self.state == "wedged":
            self.held[seq] = desc
            self.note("%s held (wedged)" % desc)
            return
        if bm == 0x80 and br == 0 and getattr(self, "arm_status", False):   # armed (system sleep)
            self.arm_status = False
            self.resumes += 1
            self.state = "wedged"
            self.held[seq] = "GET_STATUS (armed)"
            self.note("armed GET_STATUS held, device wedged")
            return
        if bm == 0x80 and br == 0 and self.suspended:          # resume check
            self.resumes += 1
            self.suspended = False
            if self.fail_at and self.resumes == self.fail_at:
                self.state = "wedged"
                self.held[seq] = "GET_STATUS of resume #%d" % self.resumes
                self.note("resume #%d: GET_STATUS held, device wedged" % self.resumes)
                return
            self.note("resume #%d: GET_STATUS answered" % self.resumes)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.ret_submit(seq, -32, 0)
                return
            d = d[:wl]
            self.ret_submit(seq, 0, len(d), d)
        elif bm == 0x00 and br == 9:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x01 and br == 11:
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 3 and wv == 1:               # SET_FEATURE(REMOTE_WAKEUP)
            self.suspends += 1
            self.suspended = True
            self.note("suspend #%d (SET_FEATURE remote wakeup)" % self.suspends)
            self.ret_submit(seq, 0, 0)
        elif bm == 0x00 and br == 1 and wv == 1:               # CLEAR_FEATURE(REMOTE_WAKEUP)
            self.ret_submit(seq, 0, 0)
        elif bm & 0x60 == 0 and br in (1, 3):
            self.ret_submit(seq, 0, 0)
        elif bm == 0x80 and br == 0:
            self.ret_submit(seq, 0, 2, b"\x03\x00")            # self-powered, remote wakeup on
        elif bm == 0x80 and br == 8:
            self.ret_submit(seq, 0, 1, b"\x01")
        elif bm == 0x81 and br == 10:
            self.ret_submit(seq, 0, 1, b"\x00")
        elif bm == 0xC0 and br == 0x09:                        # QCA_GET_TARGET_VERSION
            self.ret_submit(seq, 0, min(wl, len(QCA_VERSION)), QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:                        # QCA_CHECK_STATUS
            self.ret_submit(seq, 0, 1, b"\xc0")
        elif bm == 0x20 and br == 0:                           # HCI command
            op, plen = struct.unpack("<HB", data[:3])
            self.hci_cmds.append((mono(), op))
            if self.hold_hci and self.suspends and self.resumes >= self.fail_at > 0:
                self.held[seq] = "HCI 0x%04x" % op
                return
            self.ret_submit(seq, 0, len(data))
            if self.drop_op == op:                             # transfer done, event never sent
                self.drop_op = None
                self.note("HCI 0x%04x: control transfer completed, event dropped" % op)
                if self.wedge_until_reset:
                    self.hci_wedged = True
                    self.note("wedged: later HCI commands complete their transfer, no events, until a reset")
                return
            if self.hci_wedged:
                self.note("HCI 0x%04x: control transfer completed, no event (wedged)" % op)
                return
            self.hci_cmd(op, data[3:3 + plen])
        else:
            log("%s not handled" % desc)
            self.ret_submit(seq, -32, 0)

    # -- events
    def event(self, code, params):
        if self.hci_wedged:
            return
        with self.lock:
            self.intr_out += bytes([code, len(params)]) + params
        self.pump()

    def pump(self):
        while True:
            with self.lock:
                if self.state != "healthy" or not self.intr_pending or not self.intr_out:
                    return
                seq, buflen = self.intr_pending.popleft()
                chunk = bytes(self.intr_out[:min(buflen, 16)])
                del self.intr_out[:len(chunk)]
            self.ret_submit(seq, 0, len(chunk), chunk)

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci_cmd(self, op, p):
        log("HCI cmd 0x%04x %s" % (op, p.hex()))
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))  # QCA, 4.0
        elif op == 0x1002:
            cmds = bytearray(64)
            cmds[9] = 0x04
            self.cc(op, b"\0" + bytes(cmds))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"bt17-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            if op not in self.unknown:
                self.unknown.add(op)
                log("HCI command 0x%04x: generic Command Complete" % op)
            self.cc(op)


# ---------------------------------------------------------------- MGMT (control channel)
AF_BLUETOOTH, BTPROTO_HCI = 31, 1
HCI_CHANNEL_CONTROL, HCI_DEV_NONE = 3, 0xFFFF
MGMT_EV = {1: "Command Complete", 2: "Command Status", 4: "Index Added", 5: "Index Removed",
           6: "New Settings", 7: "Class Of Device Changed"}


class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(AF_BLUETOOTH, socket.SOCK_RAW | socket.SOCK_CLOEXEC, BTPROTO_HCI)
        if self.fd < 0:
            raise OSError(ctypes.get_errno(), "mgmt socket")
        addr = struct.pack("<HHH", AF_BLUETOOTH, HCI_DEV_NONE, HCI_CHANNEL_CONTROL)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []        # (mono, event, opcode, status, index)
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        log("MGMT send opcode 0x%04x index %d params %s" % (op, index, params.hex()))
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            try:
                b = os.read(self.fd, 1024)
            except OSError as e:
                log("mgmt read ended: %r" % (e,))
                return
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            name = MGMT_EV.get(ev, "event 0x%04x" % ev)
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT %s opcode 0x%04x status 0x%02x index %d" % (name, op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT %s index %d %s" % (name, index, p.hex()))

    def wait_reply(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op and r[1] in (1, 2):
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


# ---------------------------------------------------------------- the guest side
def usb_dev():
    base = "/sys/bus/usb/devices"
    for d in sorted(os.listdir(base)):
        p = os.path.join(base, d, "idVendor")
        try:
            if open(p).read().strip() == "13d3":
                return os.path.join(base, d)
        except OSError:
            pass
    return None


def rd(path):
    try:
        return open(path).read().strip()
    except OSError as e:
        return "<%s>" % e.strerror


def power_state(dev):
    return {k: rd(os.path.join(dev, "power", k)) for k in
            ("control", "runtime_status", "autosuspend_delay_ms", "persist", "wakeup")}


def wait_for(cond, timeout, step=0.05):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(step)
    return False


def dyndbg(lines):
    try:
        with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
            for l in lines:
                f.write(l + "\n")
        log("dyndbg: " + " | ".join(lines))
    except OSError as e:
        log("dyndbg failed: %r" % (e,))


def kmsg_mark(text):
    try:
        with open("/dev/kmsg", "w") as f:
            f.write("bt17-emu: %s\n" % text)
    except OSError:
        pass


def bring_up(emu, m):
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0: btusb did not bind")
        os.system("dmesg | tail -n 60")
        sys.exit(2)
    log("hci0 present")
    # Set Powered only after the MGMT index exists (status 0x11 Invalid Index before it), and
    # before the kernel's 2 s auto-off closes the device again
    wait_for(lambda: any(r[1] == 4 for r in m.replies), 10)
    for attempt in range(20):
        m.send(0x0005, 0, b"\x01")                # Set Powered
        r = m.wait_reply(0x0005, 15)
        log("Set Powered reply: %s" % (r,))
        if r and r[3] == 0:
            break
        time.sleep(0.2)
    dev = usb_dev()
    log("usb device %s power %s" % (dev, power_state(dev)))
    return dev


def wait_suspended(dev, timeout=15):
    ok = wait_for(lambda: rd(os.path.join(dev, "power", "runtime_status")) == "suspended", timeout)
    log("runtime_status %s after waiting (ok=%s)" % (rd(os.path.join(dev, "power", "runtime_status")), ok))
    return ok


def class_write(m, minor):
    """MGMT Set Device Class: major 1 (Computer), minor varies, so the class really changes"""
    t = mono()
    kmsg_mark("Set Device Class minor %d sent at mono %.6f" % (minor, t))
    m.send(0x000E, 0, bytes([1, minor]))
    return t


def scenario_bt17(emu, m, dev):
    res = {}
    if not wait_suspended(dev):
        log("RESULT bt17 SKIP device never autosuspended")
        return False
    time.sleep(1.0)
    t_send = class_write(m, 0x0C)
    r = m.wait_reply(0x000E, 25)
    res["reply"] = r
    log("Set Device Class reply after %.3f s: %s" % ((r[0] - t_send) if r else -1, r))
    # what bluetoothd would do next on the laptop: more class writes (Remove UUID)
    for minor in (0x04, 0x08):
        t2 = class_write(m, minor)
        r2 = m.wait_reply(0x000E, 6)
        log("follow-up class write minor %d reply after %.3f s: %s" % (minor, (r2[0] - t2) if r2 else -1, r2))
    gone = wait_for(lambda: not os.path.exists("/sys/class/bluetooth/hci0"), 25)
    log("hci0 removed: %s; usb device now %s" % (gone, usb_dev()))
    back = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15) if emu.recover else False
    powered, cw = False, None
    if emu.recover:
        log("hci0 back after recovery: %s" % back)
        if back:
            powered = power_on(m)
            if powered:
                t3 = class_write(m, 0x10)
                r3 = m.wait_reply(0x000E, 10)
                log("class write after recovery: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
                cw = ("0x%02x" % r3[3]) if r3 else "none"
    log("EMU suspends %d resumes %d state %s held %s" % (emu.suspends, emu.resumes, emu.state, list(emu.held.values())))
    st = ("0x%02x" % r[3]) if r else "none"
    log("RESULT bt17 fail_at=%d recover=%s class-write-status=%s hci0_removed=%s back=%s powered=%s class_write_after=%s" %
        (emu.fail_at, emu.recover, st, gone, back, powered, cw or "none"))
    # success: the dead device is removed; the recovering one is back, powered, and writes the class
    return (back and powered and cw == "0x00") if emu.recover else gone


def power_on(m, tries=20):
    """MGMT Set Powered on, retried while the MGMT index is not there yet"""
    for attempt in range(tries):
        m.send(0x0005, 0, b"\x01")
        r = m.wait_reply(0x0005, 15)
        log("Set Powered reply: %s" % (r,))
        if r and r[3] == 0:
            return True
        time.sleep(0.5)
    return False


def kernel_lines(*patterns):
    """(kernel time, line) of the dmesg lines that contain one of the patterns"""
    import re
    out = []
    for l in os.popen("dmesg --color=never").read().splitlines():
        if any(p in l for p in patterns):
            m_ = re.search(r"\[\s*([0-9.]+)\]", l)
            out.append((float(m_.group(1)) if m_ else -1.0, l))
    return out


def wedge_tail(emu, m, op, delay_ms, t_send, st, drop, sus):
    """after the settle time: MGMT Set Powered off, then on, then a class write. Usable = that
    class write returns 0x00. Records the emulator's reset sightings and the kernel's lines."""
    hci_up = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    t_off = mono()
    m.send(0x0005, 0, b"\x00")
    r_off = m.wait_reply(0x0005, 15)
    log("Set Powered off: %.3f s %s" % ((r_off[0] - t_off) if r_off else -1, r_off))
    powered = power_on(m, tries=3)
    cw = None
    if powered:
        t3 = class_write(m, 0x10)
        r3 = m.wait_reply(0x000E, 10)
        log("final class write: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
        cw = ("0x%02x" % r3[3]) if r3 else "none"
    kl = kernel_lines("tx timeout", "Resetting usb device", "not resetting", "Failed usb_autopm",
                      "reset full-speed", "USB disconnect")
    for ts, l in kl:
        log("KERNEL %s" % l)
    n_skip = len([1 for ts, l in kl if "not resetting" in l])
    n_reset = len([1 for ts, l in kl if "Resetting usb device" in l])
    tmo = [ts for ts, l in kl if "tx timeout" in l]
    seen = ",".join("%.6f" % x for x in emu.reset_seen) or "none"
    usable = cw == "0x00"
    log("RESULT dropcmd-wedge op=0x%04x delay_ms=%d send=%.6f transfer_done=%s autosuspended=%s "
        "class-write-status=%s reset_seen=%s tx_timeouts=%d (%s) not_resetting_lines=%d "
        "resetting_usb_device_lines=%d hci0=%s set_powered_off=%s powered_on=%s final_class_write=%s usable=%s" %
        (op, delay_ms, t_send, ",".join("%.6f" % x for x in drop) or "none",
         ",".join("%.6f" % x for x in sus) or "none", st, seen, len(tmo),
         ",".join("%.3f" % x for x in tmo), n_skip, n_reset, hci_up,
         ("0x%02x" % r_off[3]) if r_off else "none", powered, cw or "none", usable))
    return usable


def scenario_dropcmd(emu, m, dev, op, delay_ms, settle=15):
    """a command whose USB transfer completes but whose HCI event never comes. The runtime
    autosuspend delay is lowered (the default 2000 ms equals the 2 s HCI command timeout), the
    device is made awake by a successful class write, the drop is armed, and the next class
    write is sent at once. Does the device autosuspend before the timeout, what does
    btusb_reset() do, and does Bluetooth work afterwards?"""
    with open(os.path.join(dev, "power", "autosuspend_delay_ms"), "w") as f:
        f.write(str(delay_ms))
    log("autosuspend_delay_ms = %s" % rd(os.path.join(dev, "power", "autosuspend_delay_ms")))
    t = class_write(m, 0x04)
    r = m.wait_reply(0x000E, 10)
    log("warm-up class write: %.3f s %s; runtime_status %s" %
        ((r[0] - t) if r else -1, r, rd(os.path.join(dev, "power", "runtime_status"))))
    if not r or r[3] != 0:
        log("RESULT dropcmd SKIP warm-up class write failed")
        return False
    susp0 = emu.suspends
    emu.drop_op = op
    t_send = class_write(m, 0x08)
    r = m.wait_reply(0x000E, 25)
    t_reply = r[0] if r else None
    st = ("0x%02x" % r[3]) if r else "none"
    log("Set Device Class with dropped event: reply after %.3f s: %s" % ((t_reply - t_send) if r else -1, r))
    # the device's suspends after the send, from the emulator's own notes
    sus = [e[0] for e in emu.events if e[0] >= t_send and e[1].startswith("suspend #")]
    drop = [e[0] for e in emu.events if e[0] >= t_send and "event dropped" in e[1]]
    log("EMU send %.6f transfer_done %s autosuspend %s (suspends %d -> %d)" %
        (t_send, ["%.6f" % x for x in drop], ["%.6f" % x for x in sus], susp0, emu.suspends))
    # long enough for a reset and the rebinding that follows it
    time.sleep(settle)
    if emu.wedge_until_reset:
        return wedge_tail(emu, m, op, delay_ms, t_send, st, drop, sus)
    kl = kernel_lines("tx timeout", "Resetting usb device", "not resetting", "not resumed",
                      "Failed usb_autopm", "reset full-speed", "USB disconnect")
    for ts, l in kl:
        log("KERNEL %s" % l)
    reset = [l for ts, l in kl if "Resetting usb device" in l]
    skipped = [l for ts, l in kl if "not resetting" in l]
    tmo = [ts for ts, l in kl if "tx timeout" in l]
    hci_up = os.path.exists("/sys/class/bluetooth/hci0")
    powered, cw = False, None
    if hci_up:
        powered = power_on(m)
        if powered:
            t3 = class_write(m, 0x10)
            r3 = m.wait_reply(0x000E, 10)
            log("final class write: %.3f s %s" % ((r3[0] - t3) if r3 else -1, r3))
            cw = ("0x%02x" % r3[3]) if r3 else "none"
    usable = cw == "0x00"
    log("RESULT dropcmd op=0x%04x delay_ms=%d send=%.6f transfer_done=%s autosuspended=%s tx_timeout=%s "
        "class-write-status=%s btusb_reset=%s hci0=%s powered=%s final_class_write=%s usable=%s" %
        (op, delay_ms, t_send, ",".join("%.6f" % x for x in drop) or "none",
         ",".join("%.6f" % x for x in sus) or "none", ",".join("%.3f" % x for x in tmo) or "none", st,
         "resetting" if reset else "skipped(not resumed)" if skipped else "none", hci_up, powered, cw or "none", usable))
    return usable


def scenario_close_recover(emu, m, dev):
    """the resume that fails is started by closing hci0 (MGMT Set Powered off: btusb_close()
    takes a runtime PM reference), not by a command; the device comes back after the
    reset-resume (--recover). Then power on again and write the class: does Bluetooth work?"""
    if not wait_suspended(dev):
        log("RESULT close-recover SKIP device never autosuspended")
        return False
    time.sleep(1.0)
    t = mono()
    kmsg_mark("Set Powered off sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x00")
    r = m.wait_reply(0x0005, 25)
    log("Set Powered off reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    wait_for(lambda: emu.state == "healthy" and emu.resumes >= 1, 15)
    time.sleep(1.0)
    log("power after recovery: %s" % power_state(usb_dev() or dev))
    t = mono()
    kmsg_mark("Set Powered on sent at mono %.6f" % t)
    m.send(0x0005, 0, b"\x01")
    r = m.wait_reply(0x0005, 30)
    log("Set Powered on reply after %.3f s: %s" % ((r[0] - t) if r else -1, r))
    ok = False
    if r and r[3] == 0:
        t = class_write(m, 0x10)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after recovery: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT close-recover bluetooth_works_after=%s" % ok)
    return ok


def scenario_sysfreeze(emu, m, dev, fault):
    """a system sleep transition (pm_test=devices, freeze: devices suspended, 5 s, resumed),
    with the device kept runtime-active before it; with fault, the GET_STATUS of the system
    resume is held (and --recover makes the device answer after the reset-resume). Then:
    does Bluetooth work?"""
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    time.sleep(0.5)
    log("power before sleep: %s" % power_state(dev))
    emu.arm_status = fault
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    kmsg_mark("freeze (pm_test devices) at mono %.6f" % t)
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s" % (mono() - t))
    ok_hci = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20)
    time.sleep(2.0)
    ok = False
    if ok_hci:
        for attempt in range(10):
            m.send(0x0005, 0, b"\x01")
            r = m.wait_reply(0x0005, 15)
            log("Set Powered after resume: %s" % (r,))
            if r and r[3] == 0:
                break
            time.sleep(0.5)
        t = class_write(m, 0x14)
        r2 = m.wait_reply(0x000E, 10)
        log("class write after resume: %.3f s %s" % ((r2[0] - t) if r2 else -1, r2))
        ok = bool(r2 and r2[3] == 0)
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT sysfreeze fault=%s recover=%s hci0=%s bluetooth_works_after=%s" % (fault, emu.recover, ok_hci, ok))
    return ok


def scenario_bt23(emu, m, dev, delay_ms):
    """BT-23: a resume that completes between btusb's suspend decision and its anchoring of
    the URB. A debug-only module parameter (bt23_delay_ms) widens that window; the resume is
    forced meanwhile by writing power/control=on. Is the command answered?"""
    if not wait_suspended(dev):
        log("RESULT bt23 SKIP device never autosuspended")
        return False
    time.sleep(0.5)
    p = "/sys/module/btusb/parameters/bt23_delay_ms"
    with open(p, "w") as f:
        f.write(str(delay_ms))
    log("bt23_delay_ms = %s" % rd(p))
    box = {}

    def go():
        box["t"] = class_write(m, 0x18)
    th = threading.Thread(target=go)
    th.start()
    time.sleep(0.1)
    t = mono()
    with open(os.path.join(dev, "power", "control"), "w") as f:
        f.write("on")
    log("power/control=on written (resume forced) in %.3f s; runtime_status %s" %
        (mono() - t, rd(os.path.join(dev, "power", "runtime_status"))))
    th.join()
    r = m.wait_reply(0x000E, 8)
    with open(p, "w") as f:
        f.write("0")
    lat = (r[0] - box["t"]) if r else -1
    log("class write reply after %.3f s: %s" % (lat, r))
    st = ("0x%02x" % r[3]) if r else "none"
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT bt23 delay=%d status=%s latency=%.3f" % (delay_ms, st, lat))
    return st == "0x00"


def scenario_cycles(emu, m, dev, n):
    lat = []
    bad = 0
    for i in range(n):
        if not wait_suspended(dev):
            log("cycle %d: not suspended" % i)
            bad += 1
            continue
        t = class_write(m, (i % 3 + 1) * 4)
        r = m.wait_reply(0x000E, 10)
        if r is None or r[3] != 0:
            bad += 1
            log("cycle %d: reply %s" % (i, r))
        else:
            lat.append(r[0] - t)
    if lat:
        lat.sort()
        log("class write latency after a suspend: n=%d min %.3f median %.3f max %.3f s" %
            (len(lat), lat[0], lat[len(lat) // 2], lat[-1]))
    log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
    log("RESULT cycles n=%d failures=%d" % (n, bad))
    return bad == 0


def main():
    sc = sys.argv[1]
    emu = Emu(fail_at=int(arg("--fail-at", "0")), recover="--recover" in sys.argv,
              hold_hci="--hold-hci" in sys.argv)
    # USB core resume/reset path (what the laptop lacked), btusb's PM callbacks and the HCI
    # command worker's credit line (what the laptop had), nothing per packet
    dyndbg(["file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
            "func btusb_suspend +p", "func btusb_resume +p", "func btusb_disconnect +p",
            "func btusb_waker +p", "func hci_cmd_work +p", "func hci_cmd_timeout +p"])
    m = Mgmt()
    emu.attach()
    dev = bring_up(emu, m)
    ok = False
    try:
        ok = True                       # scenarios without a success condition (provoke, up)
        if sc == "bt17":
            ok = scenario_bt17(emu, m, dev)
        elif sc == "provoke":
            # the laptop tool, run unchanged against the emulated device
            import subprocess
            p = subprocess.run(["python3", "-I", "/root/exp/qca9377-bt-hang/scripts/bt17-provoke.py",
                                "--yes", "--interval", "3", "--hours", arg("--provoke-hours", "0.01"),
                                "--log", "/tmp/bt17-provoke"], capture_output=True, text=True)
            for line in (p.stdout + p.stderr).splitlines():
                log("PROVOKE " + line)
            log("EMU suspends %d resumes %d state %s" % (emu.suspends, emu.resumes, emu.state))
            log("RESULT provoke exit=%d failure_seen=%s" % (p.returncode, "FAILURE" in p.stdout))
        elif sc == "close-recover":
            ok = scenario_close_recover(emu, m, dev)
        elif sc == "bt23":
            ok = scenario_bt23(emu, m, dev, int(arg("--delay", "400")))
        elif sc == "sysfreeze":
            ok = scenario_sysfreeze(emu, m, dev, "--fault" in sys.argv)
        elif sc == "cycles":
            ok = scenario_cycles(emu, m, dev, int(arg("--cycles", "10")))
        elif sc in ("dropcmd", "dropcmd-wedge"):
            emu.wedge_until_reset = emu.wedge_until_reset or sc == "dropcmd-wedge"
            ok = scenario_dropcmd(emu, m, dev, int(arg("--drop-hci-event", "0x0c24"), 0),
                                  int(arg("--autosuspend-ms", "500")), int(arg("--settle", "15")))
        elif sc == "up":
            log("RESULT up ok")
        else:
            sys.exit("unknown scenario")
    except Exception as e:
        log("scenario raised %r" % (e,))
        ok = False
    log("unhandled HCI opcodes: %s" % sorted("0x%04x" % o for o in emu.unknown))
    log("---- kernel log ----")
    os.system("dmesg")
    # the host reads this line: run-guest.sh ends with it
    log("BT17-EXIT %d" % (0 if ok else 1))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
```
#### `results/bt17-emulation-2026-11-13/harness/build-guest-kernel.sh`
```sh
#!/bin/bash
# build-guest-kernel.sh <tag>
# Builds the BT-17 guest kernel from the worktree ../linux (whatever patches are applied
# now) into build/kobj (incremental), copies the image to img/bzImage-<tag>, the config to
# img/config-<tag>, and records HEAD and the modified files in img/bzImage-<tag>.commit.
set -u
w=/root/exp/agent-work/bt17-emu-20261113
t=$w/linux
obj=$w/build/kobj
tag=${1:?usage}
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/co20-diag-20261101/img/config-base "$obj/.config" || exit 2
	cat "$w/scripts/frag-bt17.config" >>"$obj/.config"
fi
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j14 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" status --short
	git -C "$t" diff --stat
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|USB_MON|USB_DUMMY_HCD|USB_RAW_GADGET)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
```
#### `results/bt17-emulation-2026-11-13/harness/frag-bt17.config`
```
# BT-17 guest: appended to the co20-diag guest config (BlueZ tester.config + SMP + dynamic debug)
# usbip virtual host controller, so that the real btusb binds to a userspace device
CONFIG_USBIP_CORE=y
CONFIG_USBIP_VHCI_HCD=y
CONFIG_USBIP_VHCI_HC_PORTS=8
CONFIG_USBIP_VHCI_NR_HCS=1
CONFIG_USB_ANNOUNCE_NEW_DEVICES=y
# as on the laptop: btusb enables runtime autosuspend at probe
CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y
# passive USB capture inside the guest
CONFIG_USB_MON=y
# for a later remote-wakeup variant: a gadget-side device on a dummy host controller
CONFIG_USB_GADGET=y
CONFIG_USB_DUMMY_HCD=y
CONFIG_USB_RAW_GADGET=y
```
#### `results/bt17-emulation-2026-11-13/harness/qemu-smp-hostcpu.sh`
```sh
#!/bin/bash
# qemu-smp-hostcpu.sh - as tmp/mesh-tester-ci/qemu-smp.sh (drops "acpi=off pci=noacpi noapic"
# from -append, adds -smp), and adds "-cpu host" at the end, so that on this Ryzen host the
# guest kernel sees X86_FEATURE_ZEN (btusb's platform_is_ryzen()).
set -u
args=()
for a in "$@"; do
	case "$a" in
	console=hvc0*)
		a="${a/ acpi=off pci=noacpi noapic/}"
		;;
	esac
	args+=("$a")
done
exec /usr/bin/qemu-system-x86_64 "${args[@]}" -smp "${QEMU_SMP:-4}" -cpu host
```
#### `results/bt17-emulation-2026-11-13/harness/rg-emu.py`
```python
#!/usr/bin/env python3
"""rg-emu.py - the emulated 13d3:3503 of bt17-emu.py on a second bus: USB Raw Gadget on
dummy_hcd (both in the guest kernel), for what usbip cannot do. vhci_hcd refuses system
suspend while a device is attached; dummy_hcd suspends once its root hub has.

Scenario sysfreeze [--reset-resume]: a system sleep transition (pm_test=devices, freeze) of
the running controller. With --reset-resume the device is given USB_QUIRK_RESET_RESUME
(usbcore.quirks "13d3:3503:b") before it enumerates, as btusb_check_needs_reset_resume() gives
the QCA ROME devices of its DMI table: the USB core then resets it at every resume. That is the
system-resume path CO-43 D changes. Then: does Bluetooth work?

Usage: rg-emu.py sysfreeze [--reset-resume]
"""
import ctypes
import fcntl
import os
import queue
import socket
import struct
import sys
import threading
import time

T0 = time.time()
LOCK = threading.Lock()


def mono():
    return time.clock_gettime(time.CLOCK_MONOTONIC)


def log(msg):
    with LOCK:
        print("%8.3f [mono %10.6f] %s" % (time.time() - T0, mono(), msg), flush=True)


def _ioc(d, nr, size):
    return (d << 30) | (size << 16) | (ord("U") << 8) | nr


RAW_INIT = _ioc(1, 0, 257)
RAW_RUN = _ioc(0, 1, 0)
RAW_EVENT_FETCH = _ioc(2, 2, 8)
RAW_EP0_WRITE = _ioc(1, 3, 8)
RAW_EP0_READ = _ioc(3, 4, 8)
RAW_EP_ENABLE = _ioc(1, 5, 9)
RAW_EP_WRITE = _ioc(1, 7, 8)
RAW_CONFIGURE = _ioc(0, 9, 0)
RAW_VBUS_DRAW = _ioc(1, 10, 4)
RAW_EP0_STALL = _ioc(0, 12, 0)
EV = {1: "CONNECT", 2: "CONTROL", 3: "SUSPEND", 4: "RESUME", 5: "RESET", 6: "DISCONNECT"}

# dummy_udc's fixed endpoints: ep1in-bulk, ep2out-bulk, ep3in-iso, ep4out-iso, ep5in-int
EP_INT_IN, EP_BULK_IN, EP_BULK_OUT, EP_ISO_IN, EP_ISO_OUT = 0x85, 0x81, 0x02, 0x83, 0x04


def epd(addr, attr, mps, ival):
    return struct.pack("<BBBBHB", 7, 5, addr, attr, mps, ival)


def iface(num, alt, neps):
    return struct.pack("<BBBBBBBBB", 9, 4, num, alt, neps, 0xE0, 1, 1, 0)


def config_desc():
    body = iface(0, 0, 3) + epd(EP_INT_IN, 3, 16, 1) + epd(EP_BULK_IN, 2, 64, 0) + epd(EP_BULK_OUT, 2, 64, 0)
    for alt, mps in enumerate((0, 9, 17, 25, 33, 49)):
        body += iface(1, alt, 2) + epd(EP_ISO_IN, 1, mps, 1) + epd(EP_ISO_OUT, 1, mps, 1)
    return struct.pack("<BBHBBBBB", 9, 2, 9 + len(body), 2, 1, 0, 0xE0, 50) + body


DEV_DESC = struct.pack("<BBHBBBBHHHBBBB", 18, 1, 0x0110, 0xE0, 1, 1, 64,
                       0x13D3, 0x3503, 0x0001, 0, 0, 0, 1)
QCA_VERSION = struct.pack("<IIIBBH4s", 0x302, 0x3E8, 0x302, 0, 0, 0, b"\0" * 4)
FEATURES = bytes([0xFF, 0xFF, 0x8F, 0xFE, 0x9B, 0xF9, 0x00, 0x00])
BDADDR = bytes([0x00, 0x00, 0x00, 0x77, 0x17, 0x01])


class Gadget:
    def __init__(self):
        self.fd = os.open("/dev/raw-gadget", os.O_RDWR)
        init = b"dummy_udc".ljust(128, b"\0") + b"dummy_udc.0".ljust(128, b"\0") + bytes([2])
        fcntl.ioctl(self.fd, RAW_INIT, init)
        fcntl.ioctl(self.fd, RAW_RUN, 0)
        self.ep_int = None
        self.events = queue.Queue()
        self.counts = {}
        self.configured = False
        threading.Thread(target=self.ep0_loop, daemon=True).start()
        threading.Thread(target=self.int_writer, daemon=True).start()

    def count(self, k):
        self.counts[k] = self.counts.get(k, 0) + 1

    def ep0_write(self, data):
        buf = bytearray(struct.pack("<HHI", 0, 0, len(data)) + data)
        return fcntl.ioctl(self.fd, RAW_EP0_WRITE, buf, True)

    def ep0_read(self, n):
        buf = bytearray(struct.pack("<HHI", 0, 0, n) + b"\0" * n)
        r = fcntl.ioctl(self.fd, RAW_EP0_READ, buf, True)
        return bytes(buf[8:8 + n]), r

    def stall(self):
        fcntl.ioctl(self.fd, RAW_EP0_STALL, 0)

    def ep0_loop(self):
        while True:
            buf = bytearray(struct.pack("<II", 0, 8) + b"\0" * 8)
            try:
                fcntl.ioctl(self.fd, RAW_EVENT_FETCH, buf, True)
            except OSError as e:
                log("event fetch ended: %r" % (e,))
                return
            typ, ln = struct.unpack("<II", buf[:8])
            name = EV.get(typ, str(typ))
            if typ != 2:
                self.count(name)
                log("GADGET event %s" % name)
                continue
            try:
                self.control(bytes(buf[8:16]))
            except OSError as e:
                log("control handling: %r" % (e,))

    def control(self, setup):
        bm, br, wv, wi, wl = struct.unpack("<BBHHH", setup)
        if bm == 0x80 and br == 6:
            t = wv >> 8
            d = DEV_DESC if t == 1 else config_desc() if t == 2 else None
            if d is None:
                self.stall()
                return
            self.ep0_write(d[:wl])
        elif bm == 0x00 and br == 9:                     # SET_CONFIGURATION
            if not self.configured:
                # a mutable buffer, so that ioctl() returns the handle, not the buffer
                self.ep_int = fcntl.ioctl(self.fd, RAW_EP_ENABLE,
                                          bytearray(epd(EP_INT_IN, 3, 16, 1) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_IN, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_EP_ENABLE, bytearray(epd(EP_BULK_OUT, 2, 64, 0) + b"\0\0"), True)
                fcntl.ioctl(self.fd, RAW_CONFIGURE, 0)
                fcntl.ioctl(self.fd, RAW_VBUS_DRAW, 50)
                self.configured = True
                log("GADGET configured, interrupt endpoint handle %d" % self.ep_int)
            self.ep0_read(0)
        elif bm == 0xC0 and br == 0x09:
            self.ep0_write(QCA_VERSION[:wl])
        elif bm == 0xC0 and br == 0x05:
            self.ep0_write(b"\xc0")
        elif bm == 0x20 and br == 0:                     # HCI command
            data, _ = self.ep0_read(wl)
            op, plen = struct.unpack("<HB", data[:3])
            self.hci(op)
        elif bm & 0x80:
            self.ep0_write(b"\0" * min(wl, 2))
        else:                                            # SET_INTERFACE, features: acknowledge
            self.ep0_read(0)

    def event(self, code, params):
        self.events.put(bytes([code, len(params)]) + params)

    def int_writer(self):
        while True:
            ev = self.events.get()
            while self.ep_int is None:
                time.sleep(0.01)
            for i in range(0, len(ev), 16):
                chunk = ev[i:i + 16]
                buf = bytearray(struct.pack("<HHI", self.ep_int, 0, len(chunk)) + chunk)
                try:
                    fcntl.ioctl(self.fd, RAW_EP_WRITE, buf, True)
                except OSError as e:
                    log("interrupt write: %r" % (e,))
                    break

    def cc(self, op, ret=b"\0"):
        self.event(0x0E, struct.pack("<BH", 1, op) + ret)

    def hci(self, op):
        self.count("hci 0x%04x" % op)
        if op == 0x1001:
            self.cc(op, struct.pack("<BBHBHH", 0, 6, 0x0302, 6, 0x0045, 0x0302))
        elif op == 0x1002:
            c = bytearray(64)
            c[9] = 0x04
            self.cc(op, b"\0" + bytes(c))
        elif op == 0x1003:
            self.cc(op, b"\0" + FEATURES)
        elif op == 0x1005:
            self.cc(op, struct.pack("<BHBHH", 0, 1021, 64, 8, 8))
        elif op == 0x1009:
            self.cc(op, b"\0" + BDADDR)
        elif op == 0x0C23:
            self.cc(op, b"\0\0\0\0")
        elif op == 0x0C14:
            self.cc(op, b"\0" + b"rg-emu".ljust(248, b"\0"))
        elif op == 0x0C25:
            self.cc(op, struct.pack("<BH", 0, 0x0060))
        elif op == 0x0C38:
            self.cc(op, b"\0\x01")
        elif op == 0x0C39:
            self.cc(op, b"\0\x01\x33\x8B\x9E")
        else:
            self.cc(op)


# ---------------------------------------------------------------- MGMT, as in bt17-emu.py
class Mgmt:
    def __init__(self):
        libc = ctypes.CDLL(None, use_errno=True)
        self.fd = libc.socket(31, socket.SOCK_RAW | socket.SOCK_CLOEXEC, 1)
        addr = struct.pack("<HHH", 31, 0xFFFF, 3)
        if libc.bind(self.fd, addr, len(addr)) < 0:
            raise OSError(ctypes.get_errno(), "mgmt bind")
        self.replies = []
        threading.Thread(target=self.reader, daemon=True).start()

    def send(self, op, index, params=b""):
        os.write(self.fd, struct.pack("<HHH", op, index, len(params)) + params)

    def reader(self):
        while True:
            b = os.read(self.fd, 1024)
            ev, index, ln = struct.unpack("<HHH", b[:6])
            p = b[6:6 + ln]
            if ev in (1, 2):
                op, st = struct.unpack("<HB", p[:3])
                self.replies.append((mono(), ev, op, st, index))
                log("MGMT reply opcode 0x%04x status 0x%02x index %d" % (op, st, index))
            else:
                self.replies.append((mono(), ev, None, None, index))
                log("MGMT event 0x%04x index %d" % (ev, index))

    def wait(self, op, timeout):
        t = time.time()
        while time.time() - t < timeout:
            for r in self.replies:
                if r[2] == op:
                    self.replies.remove(r)
                    return r
            time.sleep(0.02)
        return None


def wait_for(cond, timeout):
    t = time.time()
    while time.time() - t < timeout:
        if cond():
            return True
        time.sleep(0.05)
    return False


def power_on(m):
    for _ in range(20):
        m.send(0x0005, 0, b"\x01")
        r = m.wait(0x0005, 10)
        if r and r[3] == 0:
            return True
        time.sleep(0.3)
    return False


def class_ok(m, minor):
    m.send(0x000E, 0, bytes([1, minor]))
    r = m.wait(0x000E, 8)
    log("class write minor %d: %s" % (minor, r))
    return bool(r and r[3] == 0)


def main():
    rr = "--reset-resume" in sys.argv
    with open("/sys/kernel/debug/dynamic_debug/control", "w") as f:
        for l in ("file drivers/usb/core/hub.c +p", "file drivers/usb/core/driver.c +p",
                  "func btusb_suspend +p", "func btusb_resume +p", "func btusb_reset_resume +p",
                  "func btusb_disconnect +p", "func btusb_probe +p"):
            f.write(l + "\n")
    if rr:
        with open("/sys/module/usbcore/parameters/quirks", "w") as f:
            f.write("13d3:3503:b")
        log("usbcore quirks: %s" % open("/sys/module/usbcore/parameters/quirks").read().strip())
    m = Mgmt()
    g = Gadget()
    if not wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 20):
        log("no hci0")
        os.system("dmesg | tail -n 80")
        sys.exit(2)
    time.sleep(0.5)
    ok0 = power_on(m) and class_ok(m, 0x0C)
    log("before sleep: bluetooth works=%s" % ok0)
    with open("/sys/power/pm_test", "w") as f:
        f.write("devices")
    t = mono()
    try:
        with open("/sys/power/state", "w") as f:
            f.write("freeze")
    except OSError as e:
        log("freeze write: %r" % (e,))
    log("back from freeze after %.3f s; gadget events %s" % (mono() - t, g.counts))
    time.sleep(3.0)
    present = wait_for(lambda: os.path.exists("/sys/class/bluetooth/hci0"), 15)
    time.sleep(1.0)
    ok1 = present and power_on(m) and class_ok(m, 0x10)
    log("gadget events %s" % {k: v for k, v in g.counts.items() if not k.startswith("hci")})
    log("RESULT rg-sysfreeze reset_resume_quirk=%s before=%s after=%s slept=%.1f" %
        (rr, ok0, ok1, 0))
    os.system("dmesg")


if __name__ == "__main__":
    main()
```
#### `results/bt17-emulation-2026-11-13/harness/run-dropcmd-batch.sh`
```sh
#!/bin/bash
# run-dropcmd-batch.sh: the 2026-11-13 counterexample runs, sequentially, via run-guest.sh.
# Summary of exit codes: logs/matrix-dropcmd-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-dropcmd-batch.txt
: >"$out"
run() {
	"$w/harness/run-guest.sh" "$@" >/dev/null
	echo "$1 $2 exit=$?" >>"$out"
}
for n in 2 3; do run base "h-dropcmd-$n" dropcmd; done
for n in 1 2 3; do run ab "h-dropcmd-$n" dropcmd; done
for n in 1 2 3; do run final "h-dropcmd-$n" dropcmd; done
run final h-recover-1 bt17 --fail-at 1 --recover
cat "$out"
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest-hostcpu.sh`
```sh
#!/bin/bash
# run-guest-hostcpu.sh <same arguments as run-guest.sh>: the guest gets the host's CPU model
# (a Ryzen here), so that btusb's platform_is_ryzen() is true in the guest.
export HOSTCPU=1
exec /root/exp/agent-work/bt17-emu-20261113/scripts/run-guest.sh "$@"
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest-rg.sh`
```sh
#!/bin/bash
# run-guest-rg.sh <kernel tag> <run label> [rg-emu.py args...]
# As run-guest.sh, with scripts/rg-emu.py (Raw Gadget on dummy_hcd) as the guest's command.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
log=$w/logs/$tag-rg-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label rg-$label args $*" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/scripts/rg-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/scripts/rg-emu.py" "$@" >>"$log" 2>&1
echo "exit=$? end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|GADGET event|before sleep|back from freeze|no reset_resume|reset_resume|Resetting usb|reset full-speed|USB disconnect|failed to suspend|Traceback|Error|no hci0" "$log"
```
#### `results/bt17-emulation-2026-11-13/harness/run-guest.sh`
```sh
#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]
# One QEMU/KVM guest (4 CPUs, the project's qemu-smp.sh wrapper, BlueZ's test-runner with the
# host's root as the guest's root) running harness/bt17-emu.py <scenario> [args] as its command.
# Log: logs/<tag>-<label>.log (refuses to overwrite); the RESULT and key kernel lines printed.
set -u
ulimit -c 0
w=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
# HOSTCPU=1: the guest gets the host's CPU model (a Ryzen here), for the platform quirk
[ "${HOSTCPU:-0}" = 1 ] && q=$w/harness/qemu-smp-hostcpu.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
mkdir -p "$w/logs"
log=$w/logs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$w/img/bzImage-$tag" "$w/harness/bt17-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$w/img/bzImage-$tag" -- python3 -I "$w/harness/bt17-emu.py" "$@" >>"$log" 2>&1
runner_rc=$?
# the guest's own verdict is the BT17-EXIT line the emulator prints last (0 = success
# condition held); no such line means the guest did not finish: exit 3
echo "exit=$runner_rc end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|BT17-EXIT|EMU |MGMT (Command|Index)|command( 0x[0-9a-f]+)? tx timeout|Failed usb_autopm|Resetting usb|reset-resume|reset full-speed|USB disconnect|descriptor read|can't resume|gone after|failed: -110|btusb_waker|autoresume" "$log"
rc=3
verdict=$(grep -a -o -E "BT17-EXIT [01]" "$log" | tail -n 1)
[ "$verdict" = "BT17-EXIT 0" ] && rc=0
[ "$verdict" = "BT17-EXIT 1" ] && rc=1
echo "run-guest: $tag $label verdict=${verdict:-none} exit=$rc"
exit $rc
```
#### `results/bt17-emulation-2026-11-13/harness/run-matrix.sh`
```sh
#!/bin/bash
# run-matrix.sh <kernel tag> <first run number> <last run number>
# For each run number: the BT-17 fault (dead device), the command-started resume of a
# device that recovers, the close-started resume of a device that recovers; one guest each,
# sequentially, through run-guest.sh. Then one long healthy run (50 cycles).
# Summary: logs/matrix-<tag>-<first>-<last>.txt (the RESULT lines).
set -u
w=/root/exp/agent-work/bt17-emu-20261113
tag=${1:?usage}
a=${2:?usage}
b=${3:?usage}
out=$w/logs/matrix-$tag-$a-$b.txt
: >"$out"
failed=0
for n in $(seq "$a" "$b"); do
	for sc in "dead bt17 --fail-at 1" "recover bt17 --fail-at 1 --recover" "close close-recover --fail-at 1 --recover"; do
		set -- $sc
		label=$1
		shift
		"$w/harness/run-guest.sh" "$tag" "m-$label-$n" "$@" >/dev/null || failed=$((failed + 1))
		grep -a -h -E "RESULT|Failed usb_autopm|not resumed|Failed to resume|Resetting usb|BUG:|WARNING:|KASAN|possible circular" "$w/logs/$tag-m-$label-$n.log" |
			sed "s/^/$tag $label $n: /" >>"$out"
	done
done
"$w/harness/run-guest.sh" "$tag" "m-cycles50-$a" cycles --cycles 50 >/dev/null || failed=$((failed + 1))
grep -a -h -E "RESULT|latency|BUG:|WARNING:|KASAN" "$w/logs/$tag-m-cycles50-$a.log" | sed "s/^/$tag cycles50: /" >>"$out"
echo "matrix $tag $a-$b done: $out; non-zero runs: $failed"
[ "$failed" -eq 0 ]
```
#### `results/bt17-emulation-2026-11-13/harness/run-wedge-batch.sh`
```sh
#!/bin/bash
# run-wedge-batch.sh: the dropcmd-wedge runs (base 2-3 here; base 1 was run by hand), via run-guest.sh.
# Summary of exit codes: logs/matrix-wedge-batch.txt
set -u
w=/root/exp/agent-work/bt17-emu-20261113
out=$w/logs/matrix-wedge-batch.txt
: >"$out"
run() {
	"$w/harness/run-guest.sh" "$@" >/dev/null
	echo "$1 $2 exit=$?" >>"$out"
}
for n in 2 3; do run base "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
for n in 1 2 3; do run ab "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
for n in 1 2 3; do run final "h-wedge-$n" dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset; done
echo done >>"$out"
```
#### `results/bt17-emulation-2026-11-13/harness/wait-batch.sh`
```sh
#!/bin/bash
# wait-batch.sh <summary file> <last-line text>: returns when the batch has written its last line
f=${1:?usage}
until grep -q "${2:?usage}" "$f"; do sleep 10; done
cat "$f"
```

## 6. Representative test logs (kernel and emulator lines)
Full logs: `results/bt17-emulation-2026-11-13/logs/runs/`, with `SHA256SUMS` and `SHA256SUMS-hardened`.
#### `results/bt17-emulation-2026-11-13/logs/runs/base-h-wedge-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
start 2026-11-13 18:24:41 kernel base label h-wedge-1 args dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset cpus 4
Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
Running command python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.427 [mono   3.069372] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.453 [mono   3.095215] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.453 [mono   3.095659] autosuspend_delay_ms = 500
   0.455 [mono   3.097341] MGMT Command Complete opcode 0x000e status 0x00 index 0
   0.478 [mono   3.120045] EMU HCI 0x0c24: control transfer completed, event dropped
   0.478 [mono   3.120217] EMU wedged: later HCI commands complete their transfer, no events, until a reset
   0.998 [mono   3.640351] EMU ctl while wedged: control 00 03 0001 0000 0000
   0.998 [mono   3.640587] EMU suspend #1 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   2.479 [mono   5.121167] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
   2.497 [mono   5.139498] EMU send 3.119103 transfer_done ['3.120043'] autosuspend ['3.640585'] (suspends 0 -> 1)
   2.543 [mono   5.185306] EMU ctl while wedged: control 80 00 0000 0000 0002
   2.543 [mono   5.185689] EMU resume #1: GET_STATUS answered
   2.544 [mono   5.186226] EMU ctl while wedged: control 00 01 0001 0000 0000
Bluetooth: hci0: Resetting usb device.
Bluetooth: hci0: urb ffff8880028f3000 failed to resubmit (2)
   2.695 [mono   5.337229] EMU ctl while wedged: control 80 06 0100 0000 0040
   2.831 [mono   5.473333] EMU ctl while wedged: control 80 06 0100 0000 0012
   2.832 [mono   5.474223] EMU ctl while wedged: control 80 06 0200 0000 00b1
   2.832 [mono   5.474859] EMU ctl while wedged: control 00 09 0001 0000 0000
   2.833 [mono   5.475088] EMU reset seen (SET_CONFIGURATION value 1)
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   3.347 [mono   5.989373] EMU suspend #2 (SET_FEATURE remote wakeup)
   4.915 [mono   7.557541] EMU resume #2: GET_STATUS answered
  17.501 [mono  20.143633] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  17.595 [mono  20.237155] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  17.615 [mono  20.257108] MGMT Command Complete opcode 0x000e status 0x00 index 0
  17.762 [mono  20.404877] KERNEL [    5.123028] Bluetooth: hci0: command 0x0c24 tx timeout
  17.762 [mono  20.404986] KERNEL [    5.186030] Bluetooth: hci0: Resetting usb device.
  17.763 [mono  20.405052] KERNEL [    5.336066] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
  17.763 [mono  20.405130] RESULT dropcmd-wedge op=0x0c24 delay_ms=500 send=3.119103 transfer_done=3.120043 autosuspended=3.640585 class-write-status=0x05 reset_seen=5.475082 tx_timeouts=1 (5.123) not_resetting_lines=0 resetting_usb_device_lines=1 hci0=True set_powered_off=0x00 powered_on=True final_class_write=0x00 usable=True
[    0.000000] Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.017661] Kernel command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
[    0.017809] Unknown kernel command line parameters "-I dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset' TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3", will be passed to user space.
[    0.167262] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.186731] thermal_sys: Registered thermal governor 'step_wise'
[    0.238107] ACPI: PM: (supports S0 S3 S5)
[    0.328783] Bluetooth: Core ver 2.22
[    0.328824] Bluetooth: HCI device and connection manager initialized
[    0.328840] Bluetooth: HCI socket layer initialized
[    0.328846] Bluetooth: L2CAP socket layer initialized
[    0.328870] Bluetooth: SCO socket layer initialized
[    0.590257] Bluetooth: HCI UART driver ver 2.3
[    0.590263] Bluetooth: HCI UART protocol H4 registered
[    0.590266] Bluetooth: HCI UART protocol BCSP registered
[    0.590324] Bluetooth: HCI UART protocol LL registered
[    0.590326] Bluetooth: HCI UART protocol ATH3K registered
[    0.590374] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.590422] Bluetooth: HCI UART protocol QCA registered
[    0.590425] Bluetooth: HCI UART protocol AG6XX registered
[    0.590473] Bluetooth: HCI UART protocol Marvell registered
[    0.590520] Bluetooth: HCI UART protocol AML registered
[    0.590815] usbcore: registered new interface driver btusb
[    0.592806] Bluetooth: RFCOMM socket layer initialized
[    0.592823] Bluetooth: RFCOMM ver 1.11
[    0.592836] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.592844] Bluetooth: BNEP socket layer initialized
[    0.592846] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.592853] Bluetooth: HIDP socket layer initialized
[    1.052649]     --wedge-until-reset'
[    2.649908] usb usb2: usb wakeup-resume
[    2.649948] hub 2-0:1.0: hub_resume
[    2.873903] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    2.997898] usb 2-1: SetAddress Request (2) to port 0
[    3.014472] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.015037] usb 2-1: udev 2, busnum 2, minor = 129
[    3.015047] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.015916] usb 2-1: usb_probe_device
[    3.016736] btusb 2-1:1.0: usb_probe_interface
[    3.016743] btusb 2-1:1.0: usb_probe_interface - got id
[    3.019933] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.066522] Bluetooth: MGMT ver 1.23
[    3.640177] usb 2-1: usb auto-suspend, wakeup 1
[    3.659055] hub 2-0:1.0: hub_suspend
[    5.119792] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    5.123028] Bluetooth: hci0: command 0x0c24 tx timeout
[    5.123375] hub 2-0:1.0: hub_resume
[    5.124475] usb 2-1: usb auto-resume
[    5.183858] usb 2-1: Waited 0ms for CONNECT
[    5.183876] usb 2-1: finish resume
[    5.186030] Bluetooth: hci0: Resetting usb device.
[    5.186365] btusb 2-1:1.0: forced unbind
[    5.187071] Bluetooth: hci0: urb ffff8880028f3000 failed to resubmit (2)
[    5.336066] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[    5.455892] usb 2-1: SetAddress Request (2) to port 0
[    5.475073] btusb 2-1:1.0: usb_probe_interface
[    5.475085] btusb 2-1:1.0: usb_probe_interface - got id
[    5.477615] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    5.989027] usb 2-1: usb auto-suspend, wakeup 1
[    6.006881] hub 2-0:1.0: hub_suspend
[    7.498326] hub 2-0:1.0: hub_resume
[    7.499389] usb 2-1: usb auto-resume
[    7.556432] usb 2-1: Waited 0ms for CONNECT
[    7.556442] usb 2-1: finish resume
[    8.071186] usb 2-1: usb auto-suspend, wakeup 0
[    8.086941] hub 2-0:1.0: hub_suspend
[   20.142664] Bluetooth: MGMT ver 1.23
[   20.166483] hub 2-0:1.0: hub_resume
[   20.167505] usb 2-1: usb auto-resume
[   20.226805] usb 2-1: Waited 0ms for CONNECT
[   20.226815] usb 2-1: finish resume
  17.849 [mono  20.491239] BT17-EXIT 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/ab-h-wedge-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
start 2026-11-13 18:25:51 kernel ab label h-wedge-1 args dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset cpus 4
Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
Running command python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.429 [mono   3.077780] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.455 [mono   3.103637] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.455 [mono   3.104104] autosuspend_delay_ms = 500
   0.457 [mono   3.105661] MGMT Command Complete opcode 0x000e status 0x00 index 0
   0.480 [mono   3.129012] EMU HCI 0x0c24: control transfer completed, event dropped
   0.480 [mono   3.129172] EMU wedged: later HCI commands complete their transfer, no events, until a reset
   0.984 [mono   3.632709] EMU ctl while wedged: control 00 03 0001 0000 0000
   0.984 [mono   3.633005] EMU suspend #1 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   2.509 [mono   5.158100] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
   2.511 [mono   5.159586] EMU send 3.127967 transfer_done ['3.129009'] autosuspend ['3.633004'] (suspends 0 -> 1)
  17.586 [mono  20.234727] EMU ctl while wedged: control 80 00 0000 0000 0002
  17.586 [mono  20.234993] EMU resume #1: GET_STATUS answered
  17.586 [mono  20.235345] EMU ctl while wedged: control 00 01 0001 0000 0000
  17.587 [mono  20.235875] EMU ctl while wedged: control 20 00 0000 0000 0003
  17.587 [mono  20.236152] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  18.092 [mono  20.740478] EMU ctl while wedged: control 00 03 0001 0000 0000
  18.092 [mono  20.740794] EMU suspend #2 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
Bluetooth: hci0: HCI reset during shutdown failed
  27.571 [mono  30.220157] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  27.633 [mono  30.281853] EMU ctl while wedged: control 80 00 0000 0000 0002
  27.633 [mono  30.282184] EMU resume #2: GET_STATUS answered
  27.634 [mono  30.282721] EMU ctl while wedged: control 00 01 0001 0000 0000
  27.634 [mono  30.283339] EMU ctl while wedged: control c0 09 0000 0000 0014
  27.635 [mono  30.283705] EMU ctl while wedged: control c0 05 0000 0000 0001
  27.635 [mono  30.284237] EMU ctl while wedged: control c0 09 0000 0000 0014
  27.636 [mono  30.284866] EMU ctl while wedged: control 20 00 0000 0000 0003
  27.636 [mono  30.285034] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  28.138 [mono  30.786471] EMU ctl while wedged: control 00 03 0001 0000 0000
  28.138 [mono  30.786725] EMU suspend #3 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  29.703 [mono  32.351540] EMU ctl while wedged: control 80 00 0000 0000 0002
  29.703 [mono  32.351803] EMU resume #3: GET_STATUS answered
  29.703 [mono  32.352160] EMU ctl while wedged: control 00 01 0001 0000 0000
  29.704 [mono  32.352560] MGMT Command Status opcode 0x0005 status 0x05 index 0
  30.281 [mono  32.929671] EMU ctl while wedged: control 80 00 0000 0000 0002
  30.281 [mono  32.930122] EMU ctl while wedged: control 00 01 0001 0000 0000
  30.282 [mono  32.930581] EMU ctl while wedged: control c0 09 0000 0000 0014
  30.282 [mono  32.931002] EMU ctl while wedged: control c0 05 0000 0000 0001
  30.282 [mono  32.931331] EMU ctl while wedged: control c0 09 0000 0000 0014
  30.283 [mono  32.931873] EMU ctl while wedged: control 20 00 0000 0000 0003
  30.283 [mono  32.932095] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  30.787 [mono  33.436229] EMU ctl while wedged: control 00 03 0001 0000 0000
  30.788 [mono  33.436518] EMU suspend #4 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  32.361 [mono  35.009712] EMU ctl while wedged: control 80 00 0000 0000 0002
  32.361 [mono  35.010054] EMU resume #4: GET_STATUS answered
  32.362 [mono  35.010754] EMU ctl while wedged: control 00 01 0001 0000 0000
  32.362 [mono  35.011287] MGMT Command Status opcode 0x0005 status 0x05 index 0
  32.951 [mono  35.599500] EMU ctl while wedged: control 80 00 0000 0000 0002
  32.951 [mono  35.600146] EMU ctl while wedged: control 00 01 0001 0000 0000
  32.952 [mono  35.600652] EMU ctl while wedged: control c0 09 0000 0000 0014
  32.952 [mono  35.601050] EMU ctl while wedged: control c0 05 0000 0000 0001
  32.952 [mono  35.601341] EMU ctl while wedged: control c0 09 0000 0000 0014
  32.953 [mono  35.601863] EMU ctl while wedged: control 20 00 0000 0000 0003
  32.953 [mono  35.602024] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  33.475 [mono  36.124131] EMU ctl while wedged: control 00 03 0001 0000 0000
  33.476 [mono  36.124448] EMU suspend #5 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  35.017 [mono  37.665619] EMU ctl while wedged: control 80 00 0000 0000 0002
  35.017 [mono  37.666171] EMU resume #5: GET_STATUS answered
  35.018 [mono  37.666757] EMU ctl while wedged: control 00 01 0001 0000 0000
  35.018 [mono  37.667183] MGMT Command Status opcode 0x0005 status 0x05 index 0
  35.666 [mono  38.314517] KERNEL [    5.157780] Bluetooth: hci0: command 0x0c24 tx timeout
  35.666 [mono  38.314625] KERNEL [    5.157977] Bluetooth: hci0: Device not resumed; not resetting
  35.666 [mono  38.314714] RESULT dropcmd-wedge op=0x0c24 delay_ms=500 send=3.127967 transfer_done=3.129009 autosuspended=3.633004 class-write-status=0x05 reset_seen=none tx_timeouts=1 (5.158) not_resetting_lines=1 resetting_usb_device_lines=0 hci0=True set_powered_off=0x00 powered_on=False final_class_write=none usable=False
[    0.000000] Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.017449] Kernel command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset'
[    0.017594] Unknown kernel command line parameters "-I dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset' TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3", will be passed to user space.
[    0.167547] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.186352] thermal_sys: Registered thermal governor 'step_wise'
[    0.237469] ACPI: PM: (supports S0 S3 S5)
[    0.329393] Bluetooth: Core ver 2.22
[    0.329435] Bluetooth: HCI device and connection manager initialized
[    0.329452] Bluetooth: HCI socket layer initialized
[    0.329458] Bluetooth: L2CAP socket layer initialized
[    0.329481] Bluetooth: SCO socket layer initialized
[    0.596246] Bluetooth: HCI UART driver ver 2.3
[    0.596251] Bluetooth: HCI UART protocol H4 registered
[    0.596254] Bluetooth: HCI UART protocol BCSP registered
[    0.596296] Bluetooth: HCI UART protocol LL registered
[    0.596298] Bluetooth: HCI UART protocol ATH3K registered
[    0.596339] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.596376] Bluetooth: HCI UART protocol QCA registered
[    0.596378] Bluetooth: HCI UART protocol AG6XX registered
[    0.596416] Bluetooth: HCI UART protocol Marvell registered
[    0.596457] Bluetooth: HCI UART protocol AML registered
[    0.596689] usbcore: registered new interface driver btusb
[    0.598636] Bluetooth: RFCOMM socket layer initialized
[    0.598669] Bluetooth: RFCOMM ver 1.11
[    0.598681] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.598710] Bluetooth: BNEP socket layer initialized
[    0.598712] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.598718] Bluetooth: HIDP socket layer initialized
[    1.064552]     --wedge-until-reset'
[    2.656542] usb usb2: usb wakeup-resume
[    2.656584] hub 2-0:1.0: hub_resume
[    2.878773] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    2.998753] usb 2-1: SetAddress Request (2) to port 0
[    3.015325] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.015995] usb 2-1: udev 2, busnum 2, minor = 129
[    3.016003] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.016808] usb 2-1: usb_probe_device
[    3.017635] btusb 2-1:1.0: usb_probe_interface
[    3.017644] btusb 2-1:1.0: usb_probe_interface - got id
[    3.020832] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.075224] Bluetooth: MGMT ver 1.23
[    3.632747] usb 2-1: usb auto-suspend, wakeup 1
[    3.649947] hub 2-0:1.0: hub_suspend
[    5.156785] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    5.157780] Bluetooth: hci0: command 0x0c24 tx timeout
[    5.157977] Bluetooth: hci0: Device not resumed; not resetting
[   20.171557] hub 2-0:1.0: hub_resume
[   20.172647] usb 2-1: usb auto-resume
[   20.233611] usb 2-1: Waited 0ms for CONNECT
[   20.233625] usb 2-1: finish resume
[   20.740356] usb 2-1: usb auto-suspend, wakeup 1
[   20.754610] hub 2-0:1.0: hub_suspend
[   30.212716] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   30.213068] Bluetooth: hci0: HCI reset during shutdown failed
[   30.219645] hub 2-0:1.0: hub_resume
[   30.220805] usb 2-1: usb auto-resume
[   30.280612] usb 2-1: Waited 0ms for CONNECT
[   30.280627] usb 2-1: finish resume
[   30.786300] usb 2-1: usb auto-suspend, wakeup 1
[   30.801596] hub 2-0:1.0: hub_suspend
[   32.290480] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   32.290799] hub 2-0:1.0: hub_resume
[   32.291296] usb 2-1: usb auto-resume
[   32.350481] usb 2-1: Waited 0ms for CONNECT
[   32.350493] usb 2-1: finish resume
[   32.853699] usb 2-1: usb auto-suspend, wakeup 0
[   32.869829] usb 2-1: usb auto-resume
[   32.928605] usb 2-1: Waited 0ms for CONNECT
[   32.928618] usb 2-1: finish resume
[   33.436028] usb 2-1: usb auto-suspend, wakeup 1
[   33.452693] hub 2-0:1.0: hub_suspend
[   34.948589] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   34.949040] hub 2-0:1.0: hub_resume
[   34.949973] usb 2-1: usb auto-resume
[   35.008578] usb 2-1: Waited 0ms for CONNECT
[   35.008592] usb 2-1: finish resume
[   35.522649] usb 2-1: usb auto-suspend, wakeup 0
[   35.541004] usb 2-1: usb auto-resume
[   35.598457] usb 2-1: Waited 0ms for CONNECT
[   35.598472] usb 2-1: finish resume
[   36.124107] usb 2-1: usb auto-suspend, wakeup 1
[   36.138496] hub 2-0:1.0: hub_suspend
[   37.604556] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   37.604867] hub 2-0:1.0: hub_resume
[   37.605852] usb 2-1: usb auto-resume
[   37.664551] usb 2-1: Waited 0ms for CONNECT
[   37.664565] usb 2-1: finish resume
[   38.186641] usb 2-1: usb auto-suspend, wakeup 0
[   38.205523] hub 2-0:1.0: hub_suspend
  35.763 [mono  38.411535] BT17-EXIT 1
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-h-wedge-settle60-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
start 2026-11-13 18:31:34 kernel final label h-wedge-settle60-1 args dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60 cpus 4
Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60'
Running command python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.169821] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.454 [mono   3.195032] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.454 [mono   3.195436] autosuspend_delay_ms = 500
   0.455 [mono   3.196526] MGMT Command Complete opcode 0x000e status 0x00 index 0
   0.476 [mono   3.217246] EMU HCI 0x0c24: control transfer completed, event dropped
   0.476 [mono   3.217349] EMU wedged: later HCI commands complete their transfer, no events, until a reset
   0.980 [mono   3.721016] EMU ctl while wedged: control 00 03 0001 0000 0000
   0.980 [mono   3.721219] EMU suspend #1 (SET_FEATURE remote wakeup)
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   2.496 [mono   5.237895] MGMT Command Complete opcode 0x000e status 0x05 index 0
   2.515 [mono   5.256383] EMU send 3.216583 transfer_done ['3.217243'] autosuspend ['3.721218'] (suspends 0 -> 1)
  62.588 [mono  65.329625] EMU ctl while wedged: control 80 00 0000 0000 0002
  62.589 [mono  65.329977] EMU resume #1: GET_STATUS answered
  62.589 [mono  65.330524] EMU ctl while wedged: control 00 01 0001 0000 0000
  62.590 [mono  65.331064] EMU ctl while wedged: control 20 00 0000 0000 0003
  62.590 [mono  65.331259] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  63.108 [mono  65.849221] EMU ctl while wedged: control 00 03 0001 0000 0000
  63.108 [mono  65.849450] EMU suspend #2 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
Bluetooth: hci0: HCI reset during shutdown failed
  72.586 [mono  75.326940] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  72.643 [mono  75.384864] EMU ctl while wedged: control 80 00 0000 0000 0002
  72.644 [mono  75.385081] EMU resume #2: GET_STATUS answered
  72.644 [mono  75.385490] EMU ctl while wedged: control 00 01 0001 0000 0000
  72.644 [mono  75.385865] EMU ctl while wedged: control c0 09 0000 0000 0014
  72.645 [mono  75.386089] EMU ctl while wedged: control c0 05 0000 0000 0001
  72.645 [mono  75.386271] EMU ctl while wedged: control c0 09 0000 0000 0014
  72.645 [mono  75.386585] EMU ctl while wedged: control 20 00 0000 0000 0003
  72.645 [mono  75.386676] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  73.147 [mono  75.888482] EMU ctl while wedged: control 00 03 0001 0000 0000
  73.147 [mono  75.888733] EMU suspend #3 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  74.715 [mono  77.456711] EMU ctl while wedged: control 80 00 0000 0000 0002
  74.716 [mono  77.456956] EMU resume #3: GET_STATUS answered
  74.716 [mono  77.457332] EMU ctl while wedged: control 00 01 0001 0000 0000
  74.716 [mono  77.457809] MGMT Command Status opcode 0x0005 status 0x05 index 0
  75.303 [mono  78.044703] EMU ctl while wedged: control 80 00 0000 0000 0002
  75.304 [mono  78.045141] EMU ctl while wedged: control 00 01 0001 0000 0000
  75.304 [mono  78.045511] EMU ctl while wedged: control c0 09 0000 0000 0014
  75.304 [mono  78.045813] EMU ctl while wedged: control c0 05 0000 0000 0001
  75.305 [mono  78.046127] EMU ctl while wedged: control c0 09 0000 0000 0014
  75.305 [mono  78.046597] EMU ctl while wedged: control 20 00 0000 0000 0003
  75.305 [mono  78.046736] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  75.809 [mono  78.550133] EMU ctl while wedged: control 00 03 0001 0000 0000
  75.809 [mono  78.550377] EMU suspend #4 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  77.371 [mono  80.112726] EMU ctl while wedged: control 80 00 0000 0000 0002
  77.372 [mono  80.112935] EMU resume #4: GET_STATUS answered
  77.372 [mono  80.113296] EMU ctl while wedged: control 00 01 0001 0000 0000
  77.372 [mono  80.113677] MGMT Command Status opcode 0x0005 status 0x05 index 0
  77.947 [mono  80.688701] EMU ctl while wedged: control 80 00 0000 0000 0002
  77.948 [mono  80.689181] EMU ctl while wedged: control 00 01 0001 0000 0000
  77.948 [mono  80.689604] EMU ctl while wedged: control c0 09 0000 0000 0014
  77.949 [mono  80.689996] EMU ctl while wedged: control c0 05 0000 0000 0001
  77.949 [mono  80.690208] EMU ctl while wedged: control c0 09 0000 0000 0014
  77.949 [mono  80.690503] EMU ctl while wedged: control 20 00 0000 0000 0003
  77.949 [mono  80.690622] EMU HCI 0x0c03: control transfer completed, no event (wedged)
  78.456 [mono  81.197606] EMU ctl while wedged: control 00 03 0001 0000 0000
  78.456 [mono  81.197810] EMU suspend #5 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  80.027 [mono  82.768695] EMU ctl while wedged: control 80 00 0000 0000 0002
  80.027 [mono  82.768900] EMU resume #5: GET_STATUS answered
  80.028 [mono  82.769194] EMU ctl while wedged: control 00 01 0001 0000 0000
  80.028 [mono  82.769492] MGMT Command Status opcode 0x0005 status 0x05 index 0
  80.668 [mono  83.409278] KERNEL [    5.236262] Bluetooth: hci0: command 0x0c24 tx timeout
  80.668 [mono  83.409431] KERNEL [    5.236599] Bluetooth: hci0: Device not resumed; not resetting
  80.668 [mono  83.409553] RESULT dropcmd-wedge op=0x0c24 delay_ms=500 send=3.216583 transfer_done=3.217243 autosuspended=3.721218 class-write-status=0x05 reset_seen=none tx_timeouts=1 (5.236) not_resetting_lines=1 resetting_usb_device_lines=0 hci0=True set_powered_off=0x00 powered_on=False final_class_write=none usable=False
[    0.000000] Command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60'
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.046828] Kernel command line: console=hvc0 earlyprintk=serial no_hash_pointers=1 rootfstype=9p rootflags=trans=virtio,version=9p2000.u quiet ro init=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3 TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3 -I /root/exp/agent-work/bt17-emu-20261113/harness/bt17-emu.py dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60'
[    0.046993] Unknown kernel command line parameters "-I dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset --settle 60' TESTHOME=/root/exp TESTDBUS=0 TESTDAEMON=0 TESTDBUSSESSION=0 XDG_RUNTIME_DIR=/run/user/0 TESTMONITOR=0 TESTEMULATOR=0 TESTDEVS=0 TESTAUTO=0 TESTAUDIO='' TESTARGS='python3", will be passed to user space.
[    0.216357] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.235680] thermal_sys: Registered thermal governor 'step_wise'
[    0.288216] ACPI: PM: (supports S0 S3 S5)
[    0.381403] Bluetooth: Core ver 2.22
[    0.381451] Bluetooth: HCI device and connection manager initialized
[    0.381468] Bluetooth: HCI socket layer initialized
[    0.381474] Bluetooth: L2CAP socket layer initialized
[    0.381497] Bluetooth: SCO socket layer initialized
[    0.657243] Bluetooth: HCI UART driver ver 2.3
[    0.657249] Bluetooth: HCI UART protocol H4 registered
[    0.657251] Bluetooth: HCI UART protocol BCSP registered
[    0.657295] Bluetooth: HCI UART protocol LL registered
[    0.657297] Bluetooth: HCI UART protocol ATH3K registered
[    0.657344] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.657382] Bluetooth: HCI UART protocol QCA registered
[    0.657384] Bluetooth: HCI UART protocol AG6XX registered
[    0.657423] Bluetooth: HCI UART protocol Marvell registered
[    0.657462] Bluetooth: HCI UART protocol AML registered
[    0.657707] usbcore: registered new interface driver btusb
[    0.659914] Bluetooth: RFCOMM socket layer initialized
[    0.659943] Bluetooth: RFCOMM ver 1.11
[    0.659958] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.659969] Bluetooth: BNEP socket layer initialized
[    0.659972] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.659979] Bluetooth: HIDP socket layer initialized
[    1.119869]     --wedge-until-reset
[    2.749246] usb usb2: usb wakeup-resume
[    2.749288] hub 2-0:1.0: hub_resume
[    2.973570] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.093569] usb 2-1: SetAddress Request (2) to port 0
[    3.110053] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.110599] usb 2-1: udev 2, busnum 2, minor = 129
[    3.110605] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.111267] usb 2-1: usb_probe_device
[    3.111853] btusb 2-1:1.0: usb_probe_interface
[    3.111858] btusb 2-1:1.0: usb_probe_interface - got id
[    3.114015] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.167628] Bluetooth: MGMT ver 1.23
[    3.720724] usb 2-1: usb auto-suspend, wakeup 1
[    3.738727] hub 2-0:1.0: hub_suspend
[    5.236262] Bluetooth: hci0: command 0x0c24 tx timeout
[    5.236599] Bluetooth: hci0: Device not resumed; not resetting
[    5.236620] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   65.268045] hub 2-0:1.0: hub_resume
[   65.269258] usb 2-1: usb auto-resume
[   65.328438] usb 2-1: Waited 0ms for CONNECT
[   65.328449] usb 2-1: finish resume
[   65.848898] usb 2-1: usb auto-suspend, wakeup 1
[   65.866895] hub 2-0:1.0: hub_suspend
[   75.318010] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   75.318248] Bluetooth: hci0: HCI reset during shutdown failed
[   75.326398] hub 2-0:1.0: hub_resume
[   75.327177] usb 2-1: usb auto-resume
[   75.383679] usb 2-1: Waited 0ms for CONNECT
[   75.383692] usb 2-1: finish resume
[   75.888229] usb 2-1: usb auto-suspend, wakeup 1
[   75.906944] hub 2-0:1.0: hub_suspend
[   77.397912] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   77.398183] hub 2-0:1.0: hub_resume
[   77.398819] usb 2-1: usb auto-resume
[   77.455712] usb 2-1: Waited 0ms for CONNECT
[   77.455725] usb 2-1: finish resume
[   77.959046] usb 2-1: usb auto-suspend, wakeup 0
[   77.974998] hub 2-0:1.0: hub_suspend
[   77.984080] hub 2-0:1.0: hub_resume
[   77.984751] usb 2-1: usb auto-resume
[   78.043683] usb 2-1: Waited 0ms for CONNECT
[   78.043695] usb 2-1: finish resume
[   78.549875] usb 2-1: usb auto-suspend, wakeup 1
[   78.566962] hub 2-0:1.0: hub_suspend
[   80.051676] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   80.051948] hub 2-0:1.0: hub_resume
[   80.052547] usb 2-1: usb auto-resume
[   80.111689] usb 2-1: Waited 0ms for CONNECT
[   80.111701] usb 2-1: finish resume
[   80.615064] usb 2-1: usb auto-suspend, wakeup 0
[   80.631185] usb 2-1: usb auto-resume
[   80.687705] usb 2-1: Waited 0ms for CONNECT
[   80.687717] usb 2-1: finish resume
[   81.197290] usb 2-1: usb auto-suspend, wakeup 1
[   81.211812] hub 2-0:1.0: hub_suspend
[   82.707720] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   82.707969] hub 2-0:1.0: hub_resume
[   82.708514] usb 2-1: usb auto-resume
[   82.767706] usb 2-1: Waited 0ms for CONNECT
[   82.767718] usb 2-1: finish resume
[   83.270070] usb 2-1: usb auto-suspend, wakeup 0
[   83.286002] hub 2-0:1.0: hub_suspend
  80.760 [mono  83.501424] BT17-EXIT 1
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-h-dropcmd-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.089810] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.454 [mono   3.115013] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.454 [mono   3.115578] autosuspend_delay_ms = 500
   0.456 [mono   3.117518] MGMT Command Complete opcode 0x000e status 0x00 index 0
   0.479 [mono   3.140753] EMU HCI 0x0c24: control transfer completed, event dropped
   0.999 [mono   3.660553] EMU suspend #1 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   2.494 [mono   5.154956] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
   2.518 [mono   5.179028] EMU send 3.139631 transfer_done ['3.140751'] autosuspend ['3.660549'] (suspends 0 -> 1)
   2.557 [mono   5.218610] EMU resume #1: GET_STATUS answered
Bluetooth: hci0: Resetting usb device.
Bluetooth: hci0: urb ffff888002906900 failed to resubmit (2)
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   3.358 [mono   6.019496] EMU suspend #2 (SET_FEATURE remote wakeup)
   4.931 [mono   7.592715] EMU resume #2: GET_STATUS answered
  17.639 [mono  20.299957] KERNEL [    5.156565] Bluetooth: hci0: command 0x0c24 tx timeout
  17.639 [mono  20.300129] KERNEL [    5.218710] Bluetooth: hci0: Resetting usb device.
  17.639 [mono  20.300256] KERNEL [    5.365718] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
  17.711 [mono  20.371988] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  17.731 [mono  20.392744] MGMT Command Complete opcode 0x000e status 0x00 index 0
  17.754 [mono  20.415231] RESULT dropcmd op=0x0c24 delay_ms=500 send=3.139631 transfer_done=3.140751 autosuspended=3.660549 tx_timeout=5.157 class-write-status=0x05 btusb_reset=resetting hci0=True powered=True final_class_write=0x00 usable=True
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.167177] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.182591] thermal_sys: Registered thermal governor 'step_wise'
[    0.233414] ACPI: PM: (supports S0 S3 S5)
[    0.324736] Bluetooth: Core ver 2.22
[    0.324776] Bluetooth: HCI device and connection manager initialized
[    0.324791] Bluetooth: HCI socket layer initialized
[    0.324798] Bluetooth: L2CAP socket layer initialized
[    0.324821] Bluetooth: SCO socket layer initialized
[    0.595653] Bluetooth: HCI UART driver ver 2.3
[    0.595659] Bluetooth: HCI UART protocol H4 registered
[    0.595662] Bluetooth: HCI UART protocol BCSP registered
[    0.595717] Bluetooth: HCI UART protocol LL registered
[    0.595719] Bluetooth: HCI UART protocol ATH3K registered
[    0.595769] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.595832] Bluetooth: HCI UART protocol QCA registered
[    0.595835] Bluetooth: HCI UART protocol AG6XX registered
[    0.595882] Bluetooth: HCI UART protocol Marvell registered
[    0.595932] Bluetooth: HCI UART protocol AML registered
[    0.596218] usbcore: registered new interface driver btusb
[    0.598241] Bluetooth: RFCOMM socket layer initialized
[    0.598260] Bluetooth: RFCOMM ver 1.11
[    0.598276] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.598320] Bluetooth: BNEP socket layer initialized
[    0.598324] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.598333] Bluetooth: HIDP socket layer initialized
[    2.668814] usb usb2: usb wakeup-resume
[    2.668862] hub 2-0:1.0: hub_resume
[    2.893394] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.013359] usb 2-1: SetAddress Request (2) to port 0
[    3.030083] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.031349] usb 2-1: udev 2, busnum 2, minor = 129
[    3.031358] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.032224] usb 2-1: usb_probe_device
[    3.033083] btusb 2-1:1.0: usb_probe_interface
[    3.033090] btusb 2-1:1.0: usb_probe_interface - got id
[    3.036263] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.086897] Bluetooth: MGMT ver 1.23
[    3.660340] usb 2-1: usb auto-suspend, wakeup 1
[    3.675744] hub 2-0:1.0: hub_suspend
[    5.153355] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    5.156565] Bluetooth: hci0: command 0x0c24 tx timeout
[    5.156847] hub 2-0:1.0: hub_resume
[    5.157923] usb 2-1: usb auto-resume
[    5.217360] usb 2-1: Waited 0ms for CONNECT
[    5.217373] usb 2-1: finish resume
[    5.218710] Bluetooth: hci0: Resetting usb device.
[    5.218985] btusb 2-1:1.0: forced unbind
[    5.219599] Bluetooth: hci0: urb ffff888002906900 failed to resubmit (2)
[    5.365718] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[    5.485381] usb 2-1: SetAddress Request (2) to port 0
[    5.503228] btusb 2-1:1.0: usb_probe_interface
[    5.503237] btusb 2-1:1.0: usb_probe_interface - got id
[    5.506204] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    6.019169] usb 2-1: usb auto-suspend, wakeup 1
[    6.035574] hub 2-0:1.0: hub_suspend
[    7.531966] hub 2-0:1.0: hub_resume
[    7.533038] usb 2-1: usb auto-resume
[    7.591486] usb 2-1: Waited 0ms for CONNECT
[    7.591531] usb 2-1: finish resume
[    8.107835] usb 2-1: usb auto-suspend, wakeup 0
[    8.123671] hub 2-0:1.0: hub_suspend
[   20.300002] Bluetooth: MGMT ver 1.23
[   20.300108] hub 2-0:1.0: hub_resume
[   20.300915] usb 2-1: usb auto-resume
[   20.360418] usb 2-1: Waited 0ms for CONNECT
[   20.360427] usb 2-1: finish resume
  17.852 [mono  20.513429] BT17-EXIT 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-h-dropcmd-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.090282] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.453 [mono   3.115631] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   0.453 [mono   3.116118] autosuspend_delay_ms = 500
   0.455 [mono   3.117499] MGMT Command Complete opcode 0x000e status 0x00 index 0
   0.478 [mono   3.141207] EMU HCI 0x0c24: control transfer completed, event dropped
   0.982 [mono   3.644738] EMU suspend #1 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   2.495 [mono   5.158044] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
   2.505 [mono   5.167466] EMU send 3.140396 transfer_done ['3.141204'] autosuspend ['3.644734'] (suspends 0 -> 1)
  17.630 [mono  20.292716] KERNEL [    5.157831] Bluetooth: hci0: command 0x0c24 tx timeout
  17.630 [mono  20.292836] KERNEL [    5.158071] Bluetooth: hci0: Device not resumed; not resetting
  17.631 [mono  20.293273] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  17.717 [mono  20.380125] EMU resume #1: GET_STATUS answered
  17.719 [mono  20.381965] MGMT Command Complete opcode 0x000e status 0x00 index 0
  17.726 [mono  20.388577] RESULT dropcmd op=0x0c24 delay_ms=500 send=3.140396 transfer_done=3.141204 autosuspended=3.644734 tx_timeout=5.158 class-write-status=0x05 btusb_reset=skipped(not resumed) hci0=True powered=True final_class_write=0x00 usable=True
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.167644] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.187093] thermal_sys: Registered thermal governor 'step_wise'
[    0.238505] ACPI: PM: (supports S0 S3 S5)
[    0.331472] Bluetooth: Core ver 2.22
[    0.331512] Bluetooth: HCI device and connection manager initialized
[    0.331552] Bluetooth: HCI socket layer initialized
[    0.331559] Bluetooth: L2CAP socket layer initialized
[    0.331582] Bluetooth: SCO socket layer initialized
[    0.601919] Bluetooth: HCI UART driver ver 2.3
[    0.601926] Bluetooth: HCI UART protocol H4 registered
[    0.601929] Bluetooth: HCI UART protocol BCSP registered
[    0.601982] Bluetooth: HCI UART protocol LL registered
[    0.601985] Bluetooth: HCI UART protocol ATH3K registered
[    0.602038] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.602088] Bluetooth: HCI UART protocol QCA registered
[    0.602091] Bluetooth: HCI UART protocol AG6XX registered
[    0.602137] Bluetooth: HCI UART protocol Marvell registered
[    0.602194] Bluetooth: HCI UART protocol AML registered
[    0.602490] usbcore: registered new interface driver btusb
[    0.604337] Bluetooth: RFCOMM socket layer initialized
[    0.604354] Bluetooth: RFCOMM ver 1.11
[    0.604366] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.604375] Bluetooth: BNEP socket layer initialized
[    0.604377] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.604383] Bluetooth: HIDP socket layer initialized
[    2.669402] usb usb2: usb wakeup-resume
[    2.669441] hub 2-0:1.0: hub_resume
[    2.893239] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.017267] usb 2-1: SetAddress Request (2) to port 0
[    3.033648] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.034571] usb 2-1: udev 2, busnum 2, minor = 129
[    3.034581] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.035510] usb 2-1: usb_probe_device
[    3.036423] btusb 2-1:1.0: usb_probe_interface
[    3.036432] btusb 2-1:1.0: usb_probe_interface - got id
[    3.039728] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.087669] Bluetooth: MGMT ver 1.23
[    3.644564] usb 2-1: usb auto-suspend, wakeup 1
[    3.662084] hub 2-0:1.0: hub_suspend
[    5.156776] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[    5.157831] Bluetooth: hci0: command 0x0c24 tx timeout
[    5.158071] Bluetooth: hci0: Device not resumed; not resetting
[   20.316776] hub 2-0:1.0: hub_resume
[   20.317613] usb 2-1: usb auto-resume
[   20.378961] usb 2-1: Waited 0ms for CONNECT
[   20.378976] usb 2-1: finish resume
  17.838 [mono  20.500508] BT17-EXIT 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-h-recover-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.430 [mono   3.274592] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.456 [mono   3.300304] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.433 [mono   5.277601] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.484 [mono   5.328178] runtime_status suspended after waiting (ok=True)
   3.548 [mono   6.392409] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.513 [mono   8.357285] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   7.563 [mono  10.407499] MGMT Command Complete opcode 0x000e status 0x05 index 0
   8.712 [mono  11.556595] EMU host gave up on held GET_STATUS of resume #1 (unlink)
   8.712 [mono  11.556931] EMU device recovers (--recover)
Bluetooth: hci0: Resetting usb device.
Bluetooth: hci0: Opcode 0x0c24 failed: -19
   8.975 [mono  11.819267] MGMT Command Complete opcode 0x000e status 0x03 index 0
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   9.305 [mono  12.150060] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   9.329 [mono  12.173757] MGMT Command Complete opcode 0x000e status 0x00 index 0
   9.351 [mono  12.196040] EMU suspends 1 resumes 1 state healthy held []
   9.351 [mono  12.196165] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True back=True powered=True class_write_after=0x00
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.203253] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.222638] thermal_sys: Registered thermal governor 'step_wise'
[    0.275278] ACPI: PM: (supports S0 S3 S5)
[    0.374157] Bluetooth: Core ver 2.22
[    0.374207] Bluetooth: HCI device and connection manager initialized
[    0.374223] Bluetooth: HCI socket layer initialized
[    0.374229] Bluetooth: L2CAP socket layer initialized
[    0.374257] Bluetooth: SCO socket layer initialized
[    0.647747] Bluetooth: HCI UART driver ver 2.3
[    0.647752] Bluetooth: HCI UART protocol H4 registered
[    0.647754] Bluetooth: HCI UART protocol BCSP registered
[    0.647798] Bluetooth: HCI UART protocol LL registered
[    0.647800] Bluetooth: HCI UART protocol ATH3K registered
[    0.647838] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.647891] Bluetooth: HCI UART protocol QCA registered
[    0.647894] Bluetooth: HCI UART protocol AG6XX registered
[    0.647933] Bluetooth: HCI UART protocol Marvell registered
[    0.647972] Bluetooth: HCI UART protocol AML registered
[    0.648206] usbcore: registered new interface driver btusb
[    0.650272] Bluetooth: RFCOMM socket layer initialized
[    0.650288] Bluetooth: RFCOMM ver 1.11
[    0.650299] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.650307] Bluetooth: BNEP socket layer initialized
[    0.650309] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.650316] Bluetooth: HIDP socket layer initialized
[    2.851693] usb usb2: usb wakeup-resume
[    2.851738] hub 2-0:1.0: hub_resume
[    3.075015] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.195012] usb 2-1: SetAddress Request (2) to port 0
[    3.211350] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.211978] usb 2-1: udev 2, busnum 2, minor = 129
[    3.211991] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.212940] usb 2-1: usb_probe_device
[    3.213835] btusb 2-1:1.0: usb_probe_interface
[    3.213843] btusb 2-1:1.0: usb_probe_interface - got id
[    3.217133] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.271305] Bluetooth: MGMT ver 1.23
[    5.277349] usb 2-1: usb auto-suspend, wakeup 1
[    5.294310] hub 2-0:1.0: hub_suspend
[    6.332461] hub 2-0:1.0: hub_resume
[    6.333413] usb 2-1: usb auto-resume
[    6.391242] usb 2-1: Waited 0ms for CONNECT
[    6.391256] usb 2-1: finish resume
[    8.355464] Bluetooth: hci0: command 0x0c24 tx timeout
[    8.356009] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   10.406185] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   11.556516] usb 2-1: retry with reset-resume
[   11.679501] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.799278] usb 2-1: SetAddress Request (2) to port 0
[   11.817008] btusb 2-1:1.0: no reset_resume for driver btusb?
[   11.817022] btusb 2-1:1.1: no reset_resume for driver btusb?
[   11.817090] Bluetooth: hci0: Resetting usb device.
[   11.817576] btusb 2-1:1.0: forced unbind
[   11.818195] Bluetooth: hci0: Opcode 0x0c24 failed: -19
[   11.965145] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.084756] usb 2-1: SetAddress Request (2) to port 0
[   12.102284] btusb 2-1:1.0: usb_probe_interface
[   12.102294] btusb 2-1:1.0: usb_probe_interface - got id
[   12.104573] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   12.147719] Bluetooth: MGMT ver 1.23
   9.451 [mono  12.295544] BT17-EXIT 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-h-recover-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.427 [mono   3.072448] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.453 [mono   3.097915] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.430 [mono   5.075005] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.481 [mono   5.126357] runtime_status suspended after waiting (ok=True)
   3.546 [mono   6.191038] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.518 [mono   8.163830] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Device not resumed; not resetting
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   7.567 [mono  10.211901] MGMT Command Complete opcode 0x000e status 0x05 index 0
   8.622 [mono  11.266953] EMU host gave up on held GET_STATUS of resume #1 (unlink)
   8.622 [mono  11.267265] EMU device recovers (--recover)
Bluetooth: hci0: urb ffff888002912800 failed to resubmit (2)
Bluetooth: hci0: Opcode 0x0c24 failed: -19
   8.881 [mono  11.526777] MGMT Command Complete opcode 0x000e status 0x03 index 0
   9.165 [mono  11.810838] MGMT Command Status opcode 0x0005 status 0x11 index 0Bluetooth: hci0:
   9.695 [mono  12.340086] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   9.718 [mono  12.363451] MGMT Command Complete opcode 0x000e status 0x00 index 0
   9.741 [mono  12.386153] EMU suspends 1 resumes 1 state healthy held []
   9.741 [mono  12.386357] RESULT bt17 fail_at=1 recover=True class-write-status=0x05 hci0_removed=True back=True powered=True class_write_after=0x00
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.168099] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.188013] thermal_sys: Registered thermal governor 'step_wise'
[    0.239154] ACPI: PM: (supports S0 S3 S5)
[    0.330108] Bluetooth: Core ver 2.22
[    0.330148] Bluetooth: HCI device and connection manager initialized
[    0.330164] Bluetooth: HCI socket layer initialized
[    0.330171] Bluetooth: L2CAP socket layer initialized
[    0.330195] Bluetooth: SCO socket layer initialized
[    0.602086] Bluetooth: HCI UART driver ver 2.3
[    0.602091] Bluetooth: HCI UART protocol H4 registered
[    0.602093] Bluetooth: HCI UART protocol BCSP registered
[    0.602136] Bluetooth: HCI UART protocol LL registered
[    0.602138] Bluetooth: HCI UART protocol ATH3K registered
[    0.602177] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.602219] Bluetooth: HCI UART protocol QCA registered
[    0.602221] Bluetooth: HCI UART protocol AG6XX registered
[    0.602263] Bluetooth: HCI UART protocol Marvell registered
[    0.602315] Bluetooth: HCI UART protocol AML registered
[    0.602555] usbcore: registered new interface driver btusb
[    0.604482] Bluetooth: RFCOMM socket layer initialized
[    0.604499] Bluetooth: RFCOMM ver 1.11
[    0.604510] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.604555] Bluetooth: BNEP socket layer initialized
[    0.604557] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.604564] Bluetooth: HIDP socket layer initialized
[    2.652171] usb usb2: usb wakeup-resume
[    2.652218] hub 2-0:1.0: hub_resume
[    2.873273] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    2.993109] usb 2-1: SetAddress Request (2) to port 0
[    3.009676] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.010406] usb 2-1: udev 2, busnum 2, minor = 129
[    3.010414] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.011296] usb 2-1: usb_probe_device
[    3.012075] btusb 2-1:1.0: usb_probe_interface
[    3.012083] btusb 2-1:1.0: usb_probe_interface - got id
[    3.015198] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.069494] Bluetooth: MGMT ver 1.23
[    5.074665] usb 2-1: usb auto-suspend, wakeup 1
[    5.089990] hub 2-0:1.0: hub_suspend
[    6.130391] hub 2-0:1.0: hub_resume
[    6.131323] usb 2-1: usb auto-resume
[    6.189856] usb 2-1: Waited 0ms for CONNECT
[    6.189870] usb 2-1: finish resume
[    8.162021] Bluetooth: hci0: command 0x0c24 tx timeout
[    8.162461] Bluetooth: hci0: Device not resumed; not resetting
[    8.162489] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   10.209885] Bluetooth: hci0: command 0x0c24 tx timeout
[   10.210256] Bluetooth: hci0: Device not resumed; not resetting
[   10.210324] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   11.266736] usb 2-1: retry with reset-resume
[   11.386181] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.505874] usb 2-1: SetAddress Request (2) to port 0
[   11.524132] btusb 2-1:1.0: forced unbind
[   11.525044] Bluetooth: hci0: urb ffff888002912800 failed to resubmit (2)
[   11.525661] Bluetooth: hci0: Opcode 0x0c24 failed: -19
[   11.670160] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.789870] usb 2-1: SetAddress Request (2) to port 0
[   11.807255] btusb 2-1:1.0: usb_probe_interface
[   11.807265] btusb 2-1:1.0: usb_probe_interface - got id
[   11.809993] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   12.337456] Bluetooth: MGMT ver 1.23
   9.842 [mono  12.487509] BT17-EXIT 0
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-m-close-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.427 [mono   3.180928] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.460 [mono   3.213236] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.438 [mono   5.191854] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.490 [mono   5.243436] runtime_status suspended after waiting (ok=True)
   3.564 [mono   6.318075] EMU resume #1: GET_STATUS held, device wedged
   8.772 [mono  11.525985] EMU host gave up on held GET_STATUS of resume #1 (unlink)
   8.773 [mono  11.526274] EMU device recovers (--recover)
  11.031 [mono  13.784365] EMU suspend #2 (SET_FEATURE remote wakeup)
Bluetooth: hci0: Opcode 0x0c03 failed: -110
Bluetooth: hci0: HCI reset during shutdown failed
  13.643 [mono  16.396211] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  13.703 [mono  16.456791] EMU resume #2: GET_STATUS answered
  14.663 [mono  17.416899] power after recovery: {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
Bluetooth: hci0: Opcode 0x0c03 failed: -110
  16.676 [mono  19.429756] MGMT Command Status opcode 0x0005 status 0x05 index 0
  16.682 [mono  19.435437] EMU suspends 2 resumes 2 state healthy
  16.682 [mono  19.435717] RESULT close-recover bluetooth_works_after=False
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.167369] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.192947] thermal_sys: Registered thermal governor 'step_wise'
[    0.252011] ACPI: PM: (supports S0 S3 S5)
[    0.345257] Bluetooth: Core ver 2.22
[    0.345297] Bluetooth: HCI device and connection manager initialized
[    0.345312] Bluetooth: HCI socket layer initialized
[    0.345319] Bluetooth: L2CAP socket layer initialized
[    0.345343] Bluetooth: SCO socket layer initialized
[    0.627089] Bluetooth: HCI UART driver ver 2.3
[    0.627095] Bluetooth: HCI UART protocol H4 registered
[    0.627097] Bluetooth: HCI UART protocol BCSP registered
[    0.627150] Bluetooth: HCI UART protocol LL registered
[    0.627152] Bluetooth: HCI UART protocol ATH3K registered
[    0.627191] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.627232] Bluetooth: HCI UART protocol QCA registered
[    0.627234] Bluetooth: HCI UART protocol AG6XX registered
[    0.627272] Bluetooth: HCI UART protocol Marvell registered
[    0.627311] Bluetooth: HCI UART protocol AML registered
[    0.627580] usbcore: registered new interface driver btusb
[    0.632185] Bluetooth: RFCOMM socket layer initialized
[    0.632238] Bluetooth: RFCOMM ver 1.11
[    0.632290] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.632304] Bluetooth: BNEP socket layer initialized
[    0.632307] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.632315] Bluetooth: HIDP socket layer initialized
[    2.760710] usb usb2: usb wakeup-resume
[    2.760758] hub 2-0:1.0: hub_resume
[    2.994007] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.122037] usb 2-1: SetAddress Request (2) to port 0
[    3.138645] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.139566] usb 2-1: udev 2, busnum 2, minor = 129
[    3.139575] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.140427] usb 2-1: usb_probe_device
[    3.141290] btusb 2-1:1.0: usb_probe_interface
[    3.141299] btusb 2-1:1.0: usb_probe_interface - got id
[    3.144683] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.178785] Bluetooth: MGMT ver 1.23
[    5.191615] usb 2-1: usb auto-suspend, wakeup 1
[    5.208943] hub 2-0:1.0: hub_suspend
[    6.255252] hub 2-0:1.0: hub_resume
[    6.256233] usb 2-1: usb auto-resume
[    6.316562] usb 2-1: Waited 0ms for CONNECT
[    6.316575] usb 2-1: finish resume
[   11.525929] usb 2-1: retry with reset-resume
[   11.645386] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.764790] usb 2-1: SetAddress Request (2) to port 0
[   11.782534] btusb 2-1:1.0: no reset_resume for driver btusb?
[   11.782545] btusb 2-1:1.1: no reset_resume for driver btusb?
[   13.784208] usb 2-1: usb auto-suspend, wakeup 1
[   13.799042] hub 2-0:1.0: hub_suspend
[   16.387289] Bluetooth: hci0: Opcode 0x0c03 failed: -110
[   16.387781] Bluetooth: hci0: HCI reset during shutdown failed
[   16.395699] hub 2-0:1.0: hub_resume
[   16.396845] usb 2-1: usb auto-resume
[   16.455302] usb 2-1: Waited 0ms for CONNECT
[   16.455315] usb 2-1: finish resume
[   19.427408] Bluetooth: hci0: Opcode 0x0c03 failed: -110
```
#### `results/bt17-emulation-2026-11-13/logs/runs/final-m-close-1.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.428 [mono   3.207957] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.451 [mono   3.231637] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.430 [mono   5.210519] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.481 [mono   5.261245] runtime_status suspended after waiting (ok=True)
   3.551 [mono   6.330950] EMU resume #1: GET_STATUS held, device wedged
   8.754 [mono  11.533792] EMU host gave up on held GET_STATUS of resume #1 (unlink)
   8.754 [mono  11.534112] EMU device recovers (--recover)
Bluetooth: hci0: urb ffff8880013bdd00 failed to resubmit (2)
Bluetooth: hci0: Opcode 0x0c03 failed: -19
Bluetooth: hci0: HCI reset during shutdown failed
   9.043 [mono  11.823583] MGMT Command Complete opcode 0x0005 status 0x00 index 0
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
  10.066 [mono  12.845938] power after recovery: {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
  10.068 [mono  12.848204] MGMT Command Complete opcode 0x0005 status 0x00 index 0
  10.091 [mono  12.871329] MGMT Command Complete opcode 0x000e status 0x00 index 0
  10.113 [mono  12.893041] EMU suspends 1 resumes 1 state healthy
  10.113 [mono  12.893444] RESULT close-recover bluetooth_works_after=True
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
[    0.181834] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.198914] thermal_sys: Registered thermal governor 'step_wise'
[    0.250339] ACPI: PM: (supports S0 S3 S5)
[    0.350471] Bluetooth: Core ver 2.22
[    0.350515] Bluetooth: HCI device and connection manager initialized
[    0.350531] Bluetooth: HCI socket layer initialized
[    0.350538] Bluetooth: L2CAP socket layer initialized
[    0.350562] Bluetooth: SCO socket layer initialized
[    0.649257] Bluetooth: HCI UART driver ver 2.3
[    0.649263] Bluetooth: HCI UART protocol H4 registered
[    0.649266] Bluetooth: HCI UART protocol BCSP registered
[    0.649310] Bluetooth: HCI UART protocol LL registered
[    0.649312] Bluetooth: HCI UART protocol ATH3K registered
[    0.649359] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    0.649407] Bluetooth: HCI UART protocol QCA registered
[    0.649409] Bluetooth: HCI UART protocol AG6XX registered
[    0.649447] Bluetooth: HCI UART protocol Marvell registered
[    0.649484] Bluetooth: HCI UART protocol AML registered
[    0.649723] usbcore: registered new interface driver btusb
[    0.651839] Bluetooth: RFCOMM socket layer initialized
[    0.651857] Bluetooth: RFCOMM ver 1.11
[    0.651869] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    0.651916] Bluetooth: BNEP socket layer initialized
[    0.651918] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    0.651924] Bluetooth: HIDP socket layer initialized
[    2.790074] usb usb2: usb wakeup-resume
[    2.790123] hub 2-0:1.0: hub_resume
[    3.018710] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[    3.142826] usb 2-1: SetAddress Request (2) to port 0
[    3.158986] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[    3.159442] usb 2-1: udev 2, busnum 2, minor = 129
[    3.159449] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[    3.160207] usb 2-1: usb_probe_device
[    3.160825] btusb 2-1:1.0: usb_probe_interface
[    3.160830] btusb 2-1:1.0: usb_probe_interface - got id
[    3.163191] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[    3.207801] Bluetooth: MGMT ver 1.23
[    5.213292] usb 2-1: usb auto-suspend, wakeup 1
[    5.229814] hub 2-0:1.0: hub_suspend
[    6.275128] hub 2-0:1.0: hub_resume
[    6.276086] usb 2-1: usb auto-resume
[    6.332461] usb 2-1: Waited 0ms for CONNECT
[    6.332483] usb 2-1: finish resume
[   11.536884] usb 2-1: retry with reset-resume
[   11.664186] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   11.792123] usb 2-1: SetAddress Request (2) to port 0
[   11.810853] btusb 2-1:1.0: forced unbind
[   11.811639] Bluetooth: hci0: urb ffff8880013bdd00 failed to resubmit (2)
[   11.812379] Bluetooth: hci0: Opcode 0x0c03 failed: -19
[   11.812675] Bluetooth: hci0: HCI reset during shutdown failed
[   11.960078] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   12.087709] usb 2-1: SetAddress Request (2) to port 0
[   12.105771] btusb 2-1:1.0: usb_probe_interface
[   12.105780] btusb 2-1:1.0: usb_probe_interface - got id
[   12.108247] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   12.849050] Bluetooth: MGMT ver 1.23
```
#### `results/bt17-emulation-2026-11-13/logs/runs/base-bt17-2.log`
Lines matching `RESULT|SCENARIO|step|usb 2-1|usb 1-1|btusb|Bluetooth|hci0: |tx timeout|reset|resume|suspend|disconnect|Resetting|PM: |BUG|WARNING|platform_pm|raw-gadget|not running|status 0x|EMU |Opcode|reset seen|BT17-EXIT|not resetting`, without `cmd_cnt|dyndbg:|Calibrating`, colour codes removed. 
```
Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
   0.807 [mono  13.101513] MGMT Command Complete opcode 0x0005 status 0x00 index 0
   0.841 [mono  13.135961] usb device /sys/bus/usb/devices/2-1 power {'control': 'auto', 'runtime_status': 'active', 'autosuspend_delay_ms': '2000', 'persist': '1', 'wakeup': 'disabled'}
   2.843 [mono  15.137187] EMU suspend #1 (SET_FEATURE remote wakeup)
   2.893 [mono  15.187231] runtime_status suspended after waiting (ok=True)
   3.988 [mono  16.282614] EMU resume #1: GET_STATUS held, device wedged
Bluetooth: hci0: command 0x0c24 tx timeout
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   5.991 [mono  18.286049] MGMT Command Complete opcode 0x000e status 0x05 index 0
Bluetooth: hci0: Opcode 0x0c24 failed: -110
   8.079 [mono  20.373778] MGMT Command Complete opcode 0x000e status 0x05 index 0
   9.183 [mono  21.477207] EMU host gave up on held GET_STATUS of resume #1 (unlink)
   9.184 [mono  21.478596] EMU device dead: control transfers now fail -71
   9.312 [mono  21.606999] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.323 [mono  21.617636] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.324 [mono  21.619101] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
   9.574 [mono  21.868424] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.586 [mono  21.880180] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.589 [mono  21.884069] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
   9.942 [mono  22.236284] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.944 [mono  22.238733] EMU control 80 06 0100 0000 0040 -> -71 (dead)
   9.946 [mono  22.240164] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
Bluetooth: hci0: Opcode 0x0c24 failed: -110
  10.153 [mono  22.447520] MGMT Command Complete opcode 0x000e status 0x05 index 0
  10.200 [mono  22.495122] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  10.211 [mono  22.505249] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  10.222 [mono  22.516977] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
  10.646 [mono  22.940758] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  10.656 [mono  22.950445] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  10.668 [mono  22.962845] EMU control 80 06 0100 0000 0008 -> -71 (dead)
usb 2-1: device descriptor read/8, error -71
  10.793 [mono  23.087552] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  10.794 [mono  23.088744] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  10.804 [mono  23.098666] EMU control 80 06 0100 0000 0008 -> -71 (dead)
usb 2-1: device descriptor read/8, error -71
  11.081 [mono  23.375162] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  11.087 [mono  23.381285] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  11.097 [mono  23.391849] EMU control 80 06 0100 0000 0008 -> -71 (dead)
usb 2-1: device descriptor read/8, error -71
  11.224 [mono  23.519049] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  11.237 [mono  23.531214] EMU control 80 06 0100 0000 0008 -> -71 (dead)
  11.245 [mono  23.539246] EMU control 80 06 0100 0000 0008 -> -71 (dead)
usb 2-1: device descriptor read/8, error -71
Bluetooth: hci0: Failed usb_autopm_get_interface: -16
  11.440 [mono  23.734375] EMU suspends 1 resumes 1 state dead held []
  11.449 [mono  23.743564] RESULT bt17 fail_at=1 recover=False class-write-status=0x05 hci0_removed=True
  11.557 [mono  23.851342] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  11.570 [mono  23.864328] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  11.582 [mono  23.876275] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
  11.864 [mono  24.158630] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  11.878 [mono  24.173020] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  11.898 [mono  24.192641] EMU control 80 06 0100 0000 0040 -> -71 (dead)
usb 2-1: device descriptor read/64, error -71
[    0.000000] DMI: QEMU Standard PC (Q35 + ICH9, 2009), BIOS 1.16.3-debian-1.16.3-2 04/01/2014
  12.351 [mono  24.646144] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  12.376 [mono  24.671038] EMU control 80 06 0100 0000 0040 -> -71 (dead)
  12.384 [mono  24.678960] EMU control 80 06 0100 0000 0040 -> -71 (dead)
[    0.371107] smpboot: CPU0: AMD QEMU Virtual CPU version 2.5+ (family: 0xf, model: 0x6b, stepping: 0x1)
[    0.492367] thermal_sys: Registered thermal governor 'step_wise'
[    0.826459] ACPI: PM: (supports S0 S3 S5)
[    1.205541] Bluetooth: Core ver 2.22
[    1.205671] Bluetooth: HCI device and connection manager initialized
[    1.205723] Bluetooth: HCI socket layer initialized
[    1.205758] Bluetooth: L2CAP socket layer initialized
[    1.205861] Bluetooth: SCO socket layer initialized
usb 2-1: device descriptor read/64, error -71
[    2.451727] Bluetooth: HCI UART driver ver 2.3
[    2.451747] Bluetooth: HCI UART protocol H4 registered
[    2.451753] Bluetooth: HCI UART protocol BCSP registered
[    2.451846] Bluetooth: HCI UART protocol LL registered
[    2.451851] Bluetooth: HCI UART protocol ATH3K registered
[    2.451937] Bluetooth: HCI UART protocol Three-wire (H5) registered
[    2.452019] Bluetooth: HCI UART protocol QCA registered
[    2.452023] Bluetooth: HCI UART protocol AG6XX registered
[    2.452102] Bluetooth: HCI UART protocol Marvell registered
[    2.452180] Bluetooth: HCI UART protocol AML registered
[    2.452734] usbcore: registered new interface driver btusb
[    2.466507] Bluetooth: RFCOMM socket layer initialized
[    2.466590] Bluetooth: RFCOMM ver 1.11
[    2.466630] Bluetooth: BNEP (Ethernet Emulation) ver 1.3
[    2.466652] Bluetooth: BNEP socket layer initialized
[    2.466658] Bluetooth: HIDP (Human Interface Emulation) ver 1.2
[    2.466675] Bluetooth: HIDP socket layer initialized
[   12.413515] usb usb2: usb wakeup-resume
[   12.413614] hub 2-0:1.0: hub_resume
[   12.648275] usb 2-1: new full-speed USB device number 2 using vhci_hcd
[   12.801832] usb 2-1: SetAddress Request (2) to port 0
[   12.818372] usb 2-1: New USB device found: idVendor=13d3, idProduct=3503, bcdDevice=0.01
[   12.828610] usb 2-1: udev 2, busnum 2, minor = 129
[   12.829553] usb 2-1: New USB device strings: Mfr=0, Product=0, SerialNumber=0
[   12.832978] usb 2-1: usb_probe_device
[   12.840281] btusb 2-1:1.0: usb_probe_interface
[   12.844581] btusb 2-1:1.0: usb_probe_interface - got id
[   12.856190] Bluetooth: hci0: HCI Enhanced Setup Synchronous Connection command is advertised, but not supported.
[   13.083843] Bluetooth: MGMT ver 1.23
[   15.159350] usb 2-1: usb auto-suspend, wakeup 1
[   15.174841] hub 2-0:1.0: hub_suspend
[   16.229051] hub 2-0:1.0: hub_resume
[   16.230214] usb 2-1: usb auto-resume
[   16.289472] usb 2-1: Waited 0ms for CONNECT
[   16.289501] usb 2-1: finish resume
[   18.280124] Bluetooth: hci0: command 0x0c24 tx timeout
[   18.283870] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   20.373559] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   21.488880] usb 2-1: retry with reset-resume
[   21.612566] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   21.759963] usb 2-1: device descriptor read/64, error -71
[   22.015684] usb 2-1: device descriptor read/64, error -71
[   22.243500] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   22.391495] usb 2-1: device descriptor read/64, error -71
[   22.447647] Bluetooth: hci0: Opcode 0x0c24 failed: -110
[   22.659118] usb 2-1: device descriptor read/64, error -71
[   22.930850] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   22.930950] usb 2-1: SetAddress Request (2) to port 0
[   22.971776] usb 2-1: device descriptor read/8, error -71
[   23.112688] usb 2-1: device descriptor read/8, error -71
[   23.366501] usb 2-1: reset full-speed USB device number 2 using vhci_hcd
[   23.366636] usb 2-1: SetAddress Request (2) to port 0
[   23.400683] usb 2-1: device descriptor read/8, error -71
[   23.554054] usb 2-1: device descriptor read/8, error -71
[   23.662345] usb usb2-port1: logical disconnect
[   23.662661] usb 2-1: gone after usb resume? status -19
[   23.662672] usb 2-1: can't resume, status -19
[   23.662678] usb usb2-port1: logical disconnect
[   23.662996] usb 2-1: USB disconnect, device number 2
[   23.663005] usb 2-1: unregistering device
[   23.665259] Bluetooth: hci0: Failed usb_autopm_get_interface: -16
[   23.858151] usb 2-1: new full-speed USB device number 3 using vhci_hcd
[   24.021781] usb 2-1: device descriptor read/64, error -71
[   24.329820] usb 2-1: device descriptor read/64, error -71
[   24.653457] usb 2-1: new full-speed USB device number 4 using vhci_hcd
[   25.356528] usb 2-1: device descriptor read/64, error -71
usb 2-1: enqueue for inactive port 0
usb 2-1: enqueue for inactive port 0
```

## 7. The patches, in full
Applied in this order on bluetooth-next `da3cc0258`. No Signed-off-by yet: the author adds his own when sending.
### CO-43 (btusb)
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0001-Bluetooth-btusb-Report-a-failed-resume-for-deferred-.patch`
```diff
From 71a90d1a16699a9422c5289a280fe4202211c3dc Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:24:55 +0100
Subject: [PATCH 1/5] Bluetooth: btusb: Report a failed resume for deferred
 data

When data is sent while the device is runtime suspended,
submit_or_queue_tx_urb() anchors the URB on data->deferred and
btusb_waker() resumes the device. If that resume fails, the waker
returns without a word and the URB stays deferred, so the only trace
at the default log level is the HCI command timeout two seconds later,
which points at the controller rather than at the resume.

This happened with an idle QCA9377 (13d3:3503) that did not answer the
GET_STATUS after a runtime resume: the log showed "command 0x0c24 tx
timeout" and USB resets, and nothing that said the resume had failed.

Log the error, except -EACCES: then runtime PM is disabled for a
system sleep transition, and btusb_resume() sends the deferred data
when it ends.
---
 drivers/bluetooth/btusb_main.c | 9 ++++++++-
 1 file changed, 8 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 95398e2ca..a7d36e84a 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2659,8 +2659,15 @@ static void btusb_waker(struct work_struct *work)
 	int err;
 
 	err = usb_autopm_get_interface(data->intf);
-	if (err < 0)
+	if (err < 0) {
+		/* -EACCES: runtime PM is disabled for a system sleep transition,
+		 * and btusb_resume() sends the deferred data when it ends.
+		 */
+		if (err != -EACCES)
+			bt_dev_err(data->hdev, "Failed to resume device for deferred data: %d",
+				   err);
 		return;
+	}
 
 	usb_autopm_put_interface(data->intf);
 }
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0002-Bluetooth-btusb-Don-t-reset-a-device-that-has-not-re.patch`
```diff
From 64775948647a7f234060996cb063139f767fd6ef Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:25:10 +0100
Subject: [PATCH 2/5] Bluetooth: btusb: Don't reset a device that has not
 resumed

hci_cmd_timeout() calls hdev->reset() on the ordered HCI workqueue and
restores the command credit only when it returns. btusb_reset() first
takes a runtime PM reference with usb_autopm_get_interface(). If the
command timed out because the device is still resuming, that call
waits for the resume to end. When the device does not answer, the USB
core spends more than five seconds on it (the GET_STATUS timeout, then
a reset-resume and its retries), and the HCI workqueue, including RX
and TX work, is blocked all that time.

The command that timed out never reached the controller: btusb sets
BTUSB_SUSPENDING at suspend and clears it only in btusb_resume(), and
while it is set submit_or_queue_tx_urb() parks every URB on the
deferred anchor. A failed resume is already handled by the USB core,
which tries a reset-resume and disconnects the device if that fails
too. If the reset-resume succeeds, the core rebinds the interface,
because btusb has no reset_resume callback, and the reset queued here
then resets the device a second time.

Both were seen with an emulated QCA9377 (13d3:3503) whose GET_STATUS
after a runtime resume was never answered, as on a laptop where that
controller was lost: "Failed usb_autopm_get_interface: -16" was
logged 5.4 s after the command timeout, at the disconnect; with a
device that came back after the reset-resume, "Resetting usb device."
followed the rebinding and reset it again.

So don't reset, and don't wait, while BTUSB_SUSPENDING is set.
---
 drivers/bluetooth/btusb_main.c | 17 +++++++++++++++++
 1 file changed, 17 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index a7d36e84a..9c66ab5d8 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -1098,6 +1098,23 @@ static void btusb_reset(struct hci_dev *hdev)
 	int err;
 
 	data = hci_get_drvdata(hdev);
+
+	/* The device has not finished its resume, so the command that timed
+	 * out is still waiting on the deferred anchor and never reached the
+	 * controller. A resume that fails is handled by the USB core (a
+	 * reset-resume, then a disconnect), and resetting from here would
+	 * first block the HCI workqueue until that resume has ended.
+	 *
+	 * If the interface is active although btusb_resume() never ran, the
+	 * device was reset-resumed and btusb was not called back: then the
+	 * reset below, which unbinds and rebinds btusb, is what recovers it.
+	 */
+	if (test_bit(BTUSB_SUSPENDING, &data->flags) &&
+	    !pm_runtime_active(&data->intf->dev)) {
+		bt_dev_err(hdev, "Device not resumed; not resetting");
+		return;
+	}
+
 	err = usb_autopm_get_interface(data->intf);
 	if (err) {
 		bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0003-Bluetooth-btusb-Recover-after-a-reset-resume.patch`
```diff
From 7d94e97d0a0b216380cc78a4faef70a005bc4a6b Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 05:05:15 +0100
Subject: [PATCH 3/5] Bluetooth: btusb: Recover after a reset-resume

When a runtime resume fails and USB persist is enabled, the USB core
resets the device (a reset-resume). btusb has no reset_resume
callback, so usb_resume_interface() only marks its interfaces for
rebinding. Marked interfaces are rebound after a system resume
(usb_resume_complete()) and after usb_reset_device(), but not after a
runtime resume. btusb therefore stays bound without ever being
resumed: BTUSB_SUSPENDING stays set, its suspend count is off by one,
and every URB it sends from then on is parked on the deferred anchor.
The controller answers USB requests, but Bluetooth is dead until the
device is unplugged or the machine rebooted.

With an emulated QCA9377 (13d3:3503) that answered its GET_STATUS only
after the reset-resume, closing hci0 (which runtime-resumes the
device) left it in that state: the next power-on failed with HCI Reset
timeouts that never reached the device. When the resume was started
by a command, btusb_reset() from the command timeout happened to
recover it, by resetting the device once more.

Add a reset_resume callback that resumes as usual and queues a USB
reset. With no pre_reset and post_reset callbacks, the core then
unbinds and rebinds btusb, so the controller, which the reset may have
cleared, is set up again.

At a system resume, a reset-resume was already followed by a rebinding
(usb_resume_complete()): for the devices of
btusb_needs_reset_resume_table, and for Realtek devices, whose
btusb_suspend() sets reset_resume when wakeup is disabled. With this
change those are rebound by the queued reset instead, that is after
one more USB reset. That path was not tested: the emulated device
cannot take part in a system sleep.
---
 drivers/bluetooth/btusb_main.c | 26 ++++++++++++++++++++++++++
 1 file changed, 26 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 9c66ab5d8..4d2f4e136 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -5106,6 +5106,31 @@ static int btusb_resume(struct usb_interface *intf)
 	return err;
 }
 
+static int btusb_reset_resume(struct usb_interface *intf)
+{
+	struct btusb_data *data = usb_get_intfdata(intf);
+	int err;
+
+	BT_DBG("intf %p", intf);
+
+	/* The USB core reset the device to resume it. Without this callback
+	 * it marks the interfaces for rebinding, but it rebinds them only
+	 * after a system resume: after a runtime resume btusb stayed bound
+	 * and was never resumed, with BTUSB_SUSPENDING set and every later
+	 * URB parked on the deferred anchor.
+	 *
+	 * Resume as usual, then queue a USB reset: btusb has no pre_reset
+	 * and post_reset callbacks, so the core unbinds and rebinds it, and
+	 * the controller, whose state the reset may have cleared, is set up
+	 * again.
+	 */
+	err = btusb_resume(intf);
+	if (intf == data->intf)
+		usb_queue_reset_device(intf);
+
+	return err;
+}
+
 #ifdef CONFIG_DEV_COREDUMP
 static void btusb_coredump(struct device *dev)
 {
@@ -5123,6 +5148,7 @@ static struct usb_driver btusb_driver = {
 	.disconnect	= btusb_disconnect,
 	.suspend	= pm_ptr(btusb_suspend),
 	.resume		= pm_ptr(btusb_resume),
+	.reset_resume	= pm_ptr(btusb_reset_resume),
 	.id_table	= btusb_table,
 	.supports_autosuspend = 1,
 	.disable_hub_initiated_lpm = 1,
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0004-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch`
```diff
From 3fef237b910df782f6940d7c9770fdf33bbbd758 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:42:06 +0100
Subject: [PATCH 4/5] Bluetooth: btusb: Anchor a deferred URB under txlock

submit_or_queue_tx_urb() reads BTUSB_SUSPENDING under txlock, drops
the lock, and only then anchors the URB on data->deferred.
btusb_resume() sends the deferred URBs and clears BTUSB_SUSPENDING
under txlock. If the resume completes in between, the URB is anchored
after the drain: it is not sent, and the waker it schedules finds the
device active and does nothing. The URB then waits for the next
suspend and resume, and an HCI command in it times out.

Anchor the URB in the same critical section as the decision.
btusb_resume() takes the anchor's lock inside txlock as well
(play_deferred() under txlock), so the lock order does not change.

Seen with a delay inserted after the decision and a resume forced
meanwhile: a command was parked on an active device and timed out;
with this change it was sent at that resume.
---
 drivers/bluetooth/btusb_main.c | 7 ++++++-
 1 file changed, 6 insertions(+), 1 deletion(-)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 4d2f4e136..1c1cbf6bb 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -2408,16 +2408,21 @@ static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
 	unsigned long flags;
 	bool suspending;
 
+	/* Decide and anchor under txlock: btusb_resume() sends the deferred
+	 * URBs and clears BTUSB_SUSPENDING under the same lock, so a URB
+	 * anchored after that would wait for the next resume.
+	 */
 	spin_lock_irqsave(&data->txlock, flags);
 	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
 	if (!suspending)
 		data->tx_in_flight++;
+	else
+		usb_anchor_urb(urb, &data->deferred);
 	spin_unlock_irqrestore(&data->txlock, flags);
 
 	if (!suspending)
 		return submit_tx_urb(hdev, urb);
 
-	usb_anchor_urb(urb, &data->deferred);
 	schedule_work(&data->waker);
 
 	usb_free_urb(urb);
```
#### `contributions/CO-43-btusb-runtime-resume-failure/patch/0005-Bluetooth-btusb-Disable-runtime-suspend-of-QCA9377-1.patch`
```diff
From c85b3899eb7b2dd9daa2cfa287e675911cd78607 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:30:55 +0100
Subject: [PATCH 5/5] Bluetooth: btusb: Disable runtime suspend of QCA9377
 13d3:3503 on Ryzen

RFC, not for merging as is: one occurrence on one laptop.

On a laptop with a Ryzen 7 5825U, an IMC Networks QCA9377 (13d3:3503),
a direct child of the SoC's xHCI root hub (1022:1639), was runtime
suspended for 160 s with the HCI device open and no connection. The
next command started a resume; the device did not answer its
GET_STATUS, the USB core's reset-resume failed, the device was
disconnected, and it stayed off the bus through a reboot. Only a power
cycle brought it back. The device had come back from eight runtime
suspends, of up to 71 minutes, in the boot before.

That is the failure that commit dcaf83ead130 ("Bluetooth: Properly
disable remote wakeup for MT7922/MT7925 on Ryzen platform") describes
for two MediaTek devices on Ryzen root hubs, though there the resume
was started by a remote wakeup. Apply the same condition to this device:
no runtime suspend while the HCI device is open with remote wakeup
armed, on a Ryzen platform, when it is a direct child of a root hub.

The cost is the device's runtime suspend while Bluetooth is on.
---
 drivers/bluetooth/btusb_main.c | 11 +++++++++++
 1 file changed, 11 insertions(+)

diff --git a/drivers/bluetooth/btusb_main.c b/drivers/bluetooth/btusb_main.c
index 1c1cbf6bb..2aae27d84 100644
--- a/drivers/bluetooth/btusb_main.c
+++ b/drivers/bluetooth/btusb_main.c
@@ -4683,6 +4683,17 @@ static int btusb_probe(struct usb_interface *intf,
 		hdev->reset = btusb_qca_reset;
 		hci_set_quirk(hdev, HCI_QUIRK_SIMULTANEOUS_DISCOVERY);
 		btusb_check_needs_reset_resume(intf);
+
+		/* An idle IMC Networks QCA9377 (13d3:3503) attached to a Ryzen
+		 * root hub failed to answer after a runtime resume, and only a
+		 * power cycle brought it back, as reported for MT7922/MT7925
+		 * in btusb_mtk_setup(). Keep it out of runtime suspend while
+		 * the HCI device is open.
+		 */
+		if (id->idVendor == 0x13d3 && id->idProduct == 0x3503 &&
+		    platform_is_ryzen() &&
+		    is_direct_child_of_root_hub(interface_to_usbdev(intf)))
+			set_bit(BTUSB_WAKEUP_BROKEN, &data->flags);
 	}
 
 	if (id->driver_info & BTUSB_QCA_WCN6855) {
```
### CO-44 (MGMT, and its BlueZ test)
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`
```diff
From 0c5ea70d6182733c0c8e8f24e21f23c196217c93 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 04:19:58 +0100
Subject: [PATCH] Bluetooth: MGMT: Report a timed out command as
 MGMT_STATUS_TIMEOUT

mgmt_errno_status() maps -ETIMEDOUT to MGMT_STATUS_AUTH_FAILED. The
-ETIMEDOUT comes from the HCI command layer when the controller does not
answer a command in time (__hci_cmd_sync_sk() and hci_cmd_timeout()), or
when the controller itself reports a connection timeout status, so no
authentication is involved.

As a result, when the controller stops responding, user space is told
that authentication failed. For example, a Write Class of Device that
times out during Add UUID or Remove UUID completes with 0x05 and
bluetoothd logs "Failed to remove UUID: Authentication Failed (0x05)".
This sends anyone reading the log to look at pairing and keys instead of
at the controller.

MGMT_STATUS_TIMEOUT (0x08) already exists and is what the HCI status
table in this file returns for Connection Timeout, Host Timeout and
Directed Advertising Timeout. Return it for -ETIMEDOUT as well.

Fixes: 161510ccf91c ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1")
---
 net/bluetooth/mgmt.c | 2 +-
 1 file changed, 1 insertion(+), 1 deletion(-)

diff --git a/net/bluetooth/mgmt.c b/net/bluetooth/mgmt.c
index 6ed3bf6f1..0056e3484 100644
--- a/net/bluetooth/mgmt.c
+++ b/net/bluetooth/mgmt.c
@@ -295,7 +295,7 @@ static u8 mgmt_errno_status(int err)
 	case -EBUSY:
 		return MGMT_STATUS_BUSY;
 	case -ETIMEDOUT:
-		return MGMT_STATUS_AUTH_FAILED;
+		return MGMT_STATUS_TIMEOUT;
 	case -ENOMEM:
 		return MGMT_STATUS_NO_RESOURCES;
 	case -EISCONN:
```
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch`
```diff
From a23bf35d0f96a24e6a4a346b28d330897aeee849 Mon Sep 17 00:00:00 2001
From: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>
Date: Fri, 13 Nov 2026 05:07:23 +0100
Subject: [PATCH BlueZ] mgmt-tester: Add Set Device Class timeout test

The emulated controller never answers Write Class of Device, so the
kernel's HCI command times out. Set Device Class shall then complete
with Timeout. Without the kernel change "Bluetooth: MGMT: Report a
timed out command as MGMT_STATUS_TIMEOUT" it completes with
Authentication Failed, which is what mgmt_errno_status() returns for
-ETIMEDOUT.
---
 tools/mgmt-tester.c | 34 ++++++++++++++++++++++++++++++++++
 1 file changed, 34 insertions(+)

diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..4132003fd 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -2493,6 +2493,16 @@ static const struct generic_data set_dev_class_invalid_param_test_1 = {
 	.expect_status = MGMT_STATUS_INVALID_PARAMS,
 };
 
+static const struct generic_data set_dev_class_timeout_test_1 = {
+	.setup_settings = settings_powered,
+	.send_opcode = MGMT_OP_SET_DEV_CLASS,
+	.send_param = set_dev_class_valid_param,
+	.send_len = sizeof(set_dev_class_valid_param),
+	.expect_status = MGMT_STATUS_TIMEOUT,
+	.expect_param = set_dev_class_zero_rsp,
+	.expect_len = sizeof(set_dev_class_zero_rsp),
+};
+
 static const char add_spp_uuid_param[] = {
 			0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
 			0x00, 0x10, 0x00, 0x00, 0x01, 0x11, 0x00, 0x00,
@@ -12703,6 +12713,27 @@ static bool hook_delay_cmd(const void *data, uint16_t len, void *user_data)
 	return true;
 }
 
+static bool hook_drop_cmd(const void *data, uint16_t len, void *user_data)
+{
+	tester_print("Dropping HCI command, no response from emulator");
+	return false;
+}
+
+static void test_set_dev_class_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	/* The controller never answers Write Class of Device, so the
+	 * kernel's HCI command times out and the MGMT command shall
+	 * complete with Timeout rather than Authentication Failed.
+	 */
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_PRE_CMD,
+					BT_HCI_CMD_WRITE_CLASS_OF_DEV,
+					hook_drop_cmd, NULL);
+
+	test_command_generic(test_data);
+}
+
 static void test_add_remove_device_nowait(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -14926,6 +14957,9 @@ int main(int argc, char *argv[])
 	test_bredrle("Set Device Class - Invalid parameters 1",
 				&set_dev_class_invalid_param_test_1,
 				NULL, test_command_generic);
+	test_bredrle_full("Set Device Class - Timeout 1",
+				&set_dev_class_timeout_test_1,
+				NULL, test_set_dev_class_timeout, 5);
 
 	test_bredrle("Add UUID - UUID-16 1",
 				&add_uuid16_test_1,
```
#### `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/patch/bluez-mgmt-tester-set-dev-class-timeout.diff`
```diff
diff --git a/tools/mgmt-tester.c b/tools/mgmt-tester.c
index b7126dc36..4132003fd 100644
--- a/tools/mgmt-tester.c
+++ b/tools/mgmt-tester.c
@@ -2493,6 +2493,16 @@ static const struct generic_data set_dev_class_invalid_param_test_1 = {
 	.expect_status = MGMT_STATUS_INVALID_PARAMS,
 };
 
+static const struct generic_data set_dev_class_timeout_test_1 = {
+	.setup_settings = settings_powered,
+	.send_opcode = MGMT_OP_SET_DEV_CLASS,
+	.send_param = set_dev_class_valid_param,
+	.send_len = sizeof(set_dev_class_valid_param),
+	.expect_status = MGMT_STATUS_TIMEOUT,
+	.expect_param = set_dev_class_zero_rsp,
+	.expect_len = sizeof(set_dev_class_zero_rsp),
+};
+
 static const char add_spp_uuid_param[] = {
 			0xfb, 0x34, 0x9b, 0x5f, 0x80, 0x00, 0x00, 0x80,
 			0x00, 0x10, 0x00, 0x00, 0x01, 0x11, 0x00, 0x00,
@@ -12703,6 +12713,27 @@ static bool hook_delay_cmd(const void *data, uint16_t len, void *user_data)
 	return true;
 }
 
+static bool hook_drop_cmd(const void *data, uint16_t len, void *user_data)
+{
+	tester_print("Dropping HCI command, no response from emulator");
+	return false;
+}
+
+static void test_set_dev_class_timeout(const void *test_data)
+{
+	struct test_data *data = tester_get_data();
+
+	/* The controller never answers Write Class of Device, so the
+	 * kernel's HCI command times out and the MGMT command shall
+	 * complete with Timeout rather than Authentication Failed.
+	 */
+	hciemu_add_hook(data->hciemu, HCIEMU_HOOK_PRE_CMD,
+					BT_HCI_CMD_WRITE_CLASS_OF_DEV,
+					hook_drop_cmd, NULL);
+
+	test_command_generic(test_data);
+}
+
 static void test_add_remove_device_nowait(const void *test_data)
 {
 	struct test_data *data = tester_get_data();
@@ -14926,6 +14957,9 @@ int main(int argc, char *argv[])
 	test_bredrle("Set Device Class - Invalid parameters 1",
 				&set_dev_class_invalid_param_test_1,
 				NULL, test_command_generic);
+	test_bredrle_full("Set Device Class - Timeout 1",
+				&set_dev_class_timeout_test_1,
+				NULL, test_set_dev_class_timeout, 5);
 
 	test_bredrle("Add UUID - UUID-16 1",
 				&add_uuid16_test_1,
```

## 8. The unpatched code (bluetooth-next `da3cc0258`)
Extracted with `git show da3cc0258:<path>`; each definition whole.
#### `drivers/bluetooth/btusb_main.c`: `btusb_reset` (from line 1095)
```c
static void btusb_reset(struct hci_dev *hdev)
{
	struct btusb_data *data;
	int err;

	data = hci_get_drvdata(hdev);
	err = usb_autopm_get_interface(data->intf);
	if (err) {
		bt_dev_err(hdev, "Failed usb_autopm_get_interface: %d", err);
		return;
	}

	if (test_and_set_bit(BTUSB_RESET, &data->flags))
		usb_autopm_put_interface_no_suspend(data->intf);

	bt_dev_err(hdev, "Resetting usb device.");
	usb_queue_reset_device(data->intf);
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_qca_reset` (from line 1236)
```c
static void btusb_qca_reset(struct hci_dev *hdev)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	struct gpio_desc *reset_gpio = data->reset_gpio;

	if (test_bit(BTUSB_HW_SSR_ACTIVE, &data->flags)) {
		bt_dev_info(hdev, "Ramdump in progress, defer reset");
		return;
	}

	if (reset_gpio) {
		bt_dev_err(hdev, "Reset qca device via bt_en gpio");

		/* Toggle the hard reset line. The qca bt device is going to
		 * yank itself off the USB and then replug. The cleanup is handled
		 * correctly on the way out (standard USB disconnect), and the new
		 * device is detected cleanly and bound to the driver again like
		 * it should be.
		 */
		if (test_and_set_bit(BTUSB_HW_RESET_ACTIVE, &data->flags)) {
			bt_dev_err(hdev, "last reset failed? Not resetting again");
			return;
		}

		gpiod_set_value_cansleep(reset_gpio, 0);
		msleep(200);
		gpiod_set_value_cansleep(reset_gpio, 1);

		return;
	}

	btusb_reset(hdev);
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_tx_complete` (from line 2072)
```c
static void btusb_tx_complete(struct urb *urb)
{
	struct sk_buff *skb = urb->context;
	struct hci_dev *hdev = (struct hci_dev *)skb->dev;
	struct btusb_data *data = hci_get_drvdata(hdev);
	unsigned long flags;

	BT_DBG("%s urb %p status %d count %d", hdev->name, urb, urb->status,
	       urb->actual_length);

	if (!test_bit(HCI_RUNNING, &hdev->flags))
		goto done;

	if (!urb->status) {
		hdev->stat.byte_tx += urb->transfer_buffer_length;
	} else {
		if (hci_skb_pkt_type(skb) == HCI_COMMAND_PKT)
			hci_cmd_sync_cancel(hdev, -urb->status);
		hdev->stat.err_tx++;
	}

done:
	spin_lock_irqsave(&data->txlock, flags);
	data->tx_in_flight--;
	spin_unlock_irqrestore(&data->txlock, flags);

	kfree(urb->setup_packet);

	kfree_skb(skb);
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_close` (from line 2198)
```c
static int btusb_close(struct hci_dev *hdev)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	int err;

	BT_DBG("%s", hdev->name);

	cancel_work_sync(&data->work);
	cancel_work_sync(&data->waker);

	clear_bit(BTUSB_ISOC_RUNNING, &data->flags);
	clear_bit(BTUSB_BULK_RUNNING, &data->flags);
	clear_bit(BTUSB_INTR_RUNNING, &data->flags);
	clear_bit(BTUSB_DIAG_RUNNING, &data->flags);

	btusb_stop_traffic(data);

	/* rx_work must only be canceled once the URBs that can rearm it are
	 * gone, and it must be canceled synchronously since btusb_disconnect()
	 * frees the btusb_data it dereferences right after hci_unregister_dev().
	 */
	cancel_delayed_work_sync(&data->rx_work);

	skb_queue_purge(&data->acl_q);

	btusb_free_frags(data);

	err = usb_autopm_get_interface(data->intf);
	if (err < 0)
		goto failed;

	data->intf->needs_remote_wakeup = 0;

	/* Enable remote wake up for auto-suspend */
	if (test_bit(BTUSB_WAKEUP_AUTOSUSPEND, &data->flags))
		data->intf->needs_remote_wakeup = 1;

	usb_autopm_put_interface(data->intf);

failed:
	usb_scuttle_anchored_urbs(&data->deferred);
	return 0;
}
```
#### `drivers/bluetooth/btusb_main.c`: `alloc_bulk_urb` (from line 2258)
```c
static struct urb *alloc_bulk_urb(struct hci_dev *hdev, struct sk_buff *skb)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	struct urb *urb;
	unsigned int pipe;

	if (!data->bulk_tx_ep)
		return ERR_PTR(-ENODEV);

	if (data->proto == BTUSB_PROTO_H4) {
		/* The frame type is prepended in place, so the buffer must not
		 * be shared with anyone else.
		 */
		if (skb_cow_head(skb, 1))
			return ERR_PTR(-ENOMEM);
	}

	urb = usb_alloc_urb(0, GFP_KERNEL);
	if (!urb)
		return ERR_PTR(-ENOMEM);

	pipe = usb_sndbulkpipe(data->udev, data->bulk_tx_ep->bEndpointAddress);

	if (data->proto == BTUSB_PROTO_H4) {
		/* Prepend skb with frame type */
		memcpy(skb_push(skb, 1), &hci_skb_pkt_type(skb), 1);
	}

	usb_fill_bulk_urb(urb, data->udev, pipe,
			  skb->data, skb->len, btusb_tx_complete, skb);

	skb->dev = (void *)hdev;

	return urb;
}
```
#### `drivers/bluetooth/btusb_main.c`: `alloc_ctrl_urb` (from line 2294)
```c
static struct urb *alloc_ctrl_urb(struct hci_dev *hdev, struct sk_buff *skb)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	struct usb_ctrlrequest *dr;
	struct urb *urb;
	unsigned int pipe;

	if (data->proto == BTUSB_PROTO_H4)
		return alloc_bulk_urb(hdev, skb);

	urb = usb_alloc_urb(0, GFP_KERNEL);
	if (!urb)
		return ERR_PTR(-ENOMEM);

	dr = kmalloc_obj(*dr);
	if (!dr) {
		usb_free_urb(urb);
		return ERR_PTR(-ENOMEM);
	}

	dr->bRequestType = data->cmdreq_type;
	dr->bRequest     = data->cmdreq;
	dr->wIndex       = 0;
	dr->wValue       = 0;
	dr->wLength      = __cpu_to_le16(skb->len);

	pipe = usb_sndctrlpipe(data->udev, 0x00);

	usb_fill_control_urb(urb, data->udev, pipe, (void *)dr,
			     skb->data, skb->len, btusb_tx_complete, skb);

	skb->dev = (void *)hdev;

	return urb;
}
```
#### `drivers/bluetooth/btusb_main.c`: `submit_or_queue_tx_urb` (from line 2388)
```c
static int submit_or_queue_tx_urb(struct hci_dev *hdev, struct urb *urb)
{
	struct btusb_data *data = hci_get_drvdata(hdev);
	unsigned long flags;
	bool suspending;

	spin_lock_irqsave(&data->txlock, flags);
	suspending = test_bit(BTUSB_SUSPENDING, &data->flags);
	if (!suspending)
		data->tx_in_flight++;
	spin_unlock_irqrestore(&data->txlock, flags);

	if (!suspending)
		return submit_tx_urb(hdev, urb);

	usb_anchor_urb(urb, &data->deferred);
	schedule_work(&data->waker);

	usb_free_urb(urb);
	return 0;
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_waker` (from line 2656)
```c
static void btusb_waker(struct work_struct *work)
{
	struct btusb_data *data = container_of(work, struct btusb_data, waker);
	int err;

	err = usb_autopm_get_interface(data->intf);
	if (err < 0)
		return;

	usb_autopm_put_interface(data->intf);
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_suspend` (from line 4915)
```c
static int btusb_suspend(struct usb_interface *intf, pm_message_t message)
{
	struct btusb_data *data = usb_get_intfdata(intf);

	BT_DBG("intf %p", intf);

	/*
	 * It is reported that remote wakeup events could sometimes cause some
	 * adapters completely unresponsive. Resetting the xHCI root hub doesn't
	 * help at all, and recovering from such a state needs a power cycle.
	 * Since disabling remote wakeup simply causes the USB core to gate
	 * runtime autosuspend as well due to needs_remote_wakeup == 1, let's do
	 * this ourselves to make our life easier. The interface can be safely
	 * autosuspended as long as remote wakeup is disabled, i.e., after
	 * closing the HCI device.
	 *
	 * Don't auto-suspend if there are connections or discovery in progress.
	 *
	 * External suspend calls shall never fail. Specifically, a device with
	 * broken remote wakeup may still take the advantage of remote wakeup in
	 * order to wake up the system from sleep if userspace has enabled it as
	 * a wakeup source.
	 */
	if (PMSG_IS_AUTO(message) &&
	    ((test_bit(BTUSB_WAKEUP_BROKEN, &data->flags) && data->intf->needs_remote_wakeup) ||
	     hci_conn_count(data->hdev) || hci_discovery_active(data->hdev)))
		return -EBUSY;

	if (data->suspend_count++)
		return 0;

	spin_lock_irq(&data->txlock);
	if (!(PMSG_IS_AUTO(message) && data->tx_in_flight)) {
		set_bit(BTUSB_SUSPENDING, &data->flags);
		spin_unlock_irq(&data->txlock);
	} else {
		spin_unlock_irq(&data->txlock);
		data->suspend_count--;
		return -EBUSY;
	}

	cancel_work_sync(&data->work);

	if (data->suspend)
		data->suspend(data->hdev);

	btusb_stop_traffic(data);
	usb_kill_anchored_urbs(&data->tx_anchor);

	if (data->oob_wake_irq && device_may_wakeup(&data->udev->dev)) {
		set_bit(BTUSB_OOB_WAKE_ENABLED, &data->flags);
		enable_irq_wake(data->oob_wake_irq);
		enable_irq(data->oob_wake_irq);
	}

	/* For global suspend, Realtek devices lose the loaded fw
	 * in them. But for autosuspend, firmware should remain.
	 * Actually, it depends on whether the usb host sends
	 * set feature (enable wakeup) or not.
	 */
	if (test_bit(BTUSB_WAKEUP_AUTOSUSPEND, &data->flags)) {
		if (PMSG_IS_AUTO(message) &&
		    device_can_wakeup(&data->udev->dev))
			data->udev->do_remote_wakeup = 1;
		else if (!PMSG_IS_AUTO(message) &&
			 !device_may_wakeup(&data->udev->dev)) {
			data->udev->do_remote_wakeup = 0;
			data->udev->reset_resume = 1;
		}
	}

	return 0;
}
```
#### `drivers/bluetooth/btusb_main.c`: `play_deferred` (from line 4989)
```c
static void play_deferred(struct btusb_data *data)
{
	struct urb *urb;
	int err;

	while ((urb = usb_get_from_anchor(&data->deferred))) {
		usb_anchor_urb(urb, &data->tx_anchor);

		err = usb_submit_urb(urb, GFP_ATOMIC);
		if (err < 0) {
			if (err != -EPERM && err != -ENODEV)
				BT_ERR("%s urb %p submission failed (%d)",
				       data->hdev->name, urb, -err);
			kfree(urb->setup_packet);
			usb_unanchor_urb(urb);
			usb_free_urb(urb);
			break;
		}

		data->tx_in_flight++;
		usb_free_urb(urb);
	}

	/* Cleanup the rest deferred urbs. */
	while ((urb = usb_get_from_anchor(&data->deferred))) {
		kfree(urb->setup_packet);
		usb_free_urb(urb);
	}
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_resume` (from line 5019)
```c
static int btusb_resume(struct usb_interface *intf)
{
	struct btusb_data *data = usb_get_intfdata(intf);
	struct hci_dev *hdev = data->hdev;
	int err = 0;

	BT_DBG("intf %p", intf);

	if (--data->suspend_count)
		return 0;

	/* Disable only if not already disabled (keep it balanced) */
	if (test_and_clear_bit(BTUSB_OOB_WAKE_ENABLED, &data->flags)) {
		disable_irq(data->oob_wake_irq);
		disable_irq_wake(data->oob_wake_irq);
	}

	if (!test_bit(HCI_RUNNING, &hdev->flags))
		goto done;

	if (test_bit(BTUSB_INTR_RUNNING, &data->flags)) {
		err = btusb_submit_intr_urb(hdev, GFP_NOIO);
		if (err < 0) {
			clear_bit(BTUSB_INTR_RUNNING, &data->flags);
			goto failed;
		}
	}

	if (test_bit(BTUSB_BULK_RUNNING, &data->flags)) {
		err = btusb_submit_bulk_urb(hdev, GFP_NOIO);
		if (err < 0) {
			clear_bit(BTUSB_BULK_RUNNING, &data->flags);
			goto failed;
		}

		btusb_submit_bulk_urb(hdev, GFP_NOIO);
	}

	if (test_bit(BTUSB_ISOC_RUNNING, &data->flags)) {
		if (btusb_submit_isoc_urb(hdev, GFP_NOIO) < 0)
			clear_bit(BTUSB_ISOC_RUNNING, &data->flags);
		else
			btusb_submit_isoc_urb(hdev, GFP_NOIO);
	}

	if (data->resume)
		data->resume(hdev);

	spin_lock_irq(&data->txlock);
	play_deferred(data);
	clear_bit(BTUSB_SUSPENDING, &data->flags);
	spin_unlock_irq(&data->txlock);
	schedule_work(&data->work);

	return 0;

failed:
	usb_scuttle_anchored_urbs(&data->deferred);
done:
	spin_lock_irq(&data->txlock);
	clear_bit(BTUSB_SUSPENDING, &data->flags);
	spin_unlock_irq(&data->txlock);

	return err;
}
```
#### `drivers/bluetooth/btusb_main.c`: `btusb_driver` (from line 5096)
```c
static struct usb_driver btusb_driver = {
	.name		= "btusb",
	.probe		= btusb_probe,
	.disconnect	= btusb_disconnect,
	.suspend	= pm_ptr(btusb_suspend),
	.resume		= pm_ptr(btusb_resume),
	.id_table	= btusb_table,
	.supports_autosuspend = 1,
	.disable_hub_initiated_lpm = 1,

#ifdef CONFIG_DEV_COREDUMP
	.driver = {
		.coredump = btusb_coredump,
	},
#endif
};
```
#### `net/bluetooth/hci_core.c`: `hci_cmd_timeout` (from line 1525)
```c
/* HCI command timer function */
static void hci_cmd_timeout(struct work_struct *work)
{
	struct hci_dev *hdev = container_of(work, struct hci_dev,
					    cmd_timer.work);

	if (hdev->req_skb) {
		u16 opcode = hci_skb_opcode(hdev->req_skb);

		bt_dev_err(hdev, "command 0x%4.4x tx timeout", opcode);

		hci_cmd_sync_cancel_sync(hdev, ETIMEDOUT);
	} else {
		bt_dev_err(hdev, "command tx timeout");
	}

	if (hdev->reset)
		hdev->reset(hdev);

	atomic_set(&hdev->cmd_cnt, 1);
	queue_work(hdev->workqueue, &hdev->cmd_work);
}
```
#### `net/bluetooth/hci_core.c`: `hci_cmd_work` (from line 4331)
```c
static void hci_cmd_work(struct work_struct *work)
{
	struct hci_dev *hdev = container_of(work, struct hci_dev, cmd_work);
	struct sk_buff *skb;
	int err;

	BT_DBG("%s cmd_cnt %d cmd queued %d", hdev->name,
	       atomic_read(&hdev->cmd_cnt), skb_queue_len(&hdev->cmd_q));

	/* Send queued commands */
	if (atomic_read(&hdev->cmd_cnt)) {
		skb = skb_dequeue(&hdev->cmd_q);
		if (!skb)
			return;

		err = hci_send_cmd_sync(hdev, skb);
		if (err)
			return;

		rcu_read_lock();
		if (test_bit(HCI_RESET, &hdev->flags) ||
		    hci_dev_test_flag(hdev, HCI_CMD_DRAIN_WORKQUEUE))
			cancel_delayed_work(&hdev->cmd_timer);
		else
			queue_delayed_work(hdev->workqueue, &hdev->cmd_timer,
					   HCI_CMD_TIMEOUT);
		rcu_read_unlock();
	}
}
```
#### `net/bluetooth/hci_sync.c`: `__hci_cmd_sync_sk` (from line 159)
```c
/* This function requires the caller holds hdev->req_lock. */
struct sk_buff *__hci_cmd_sync_sk(struct hci_dev *hdev, u16 opcode, u32 plen,
				  const void *param, u8 event, u32 timeout,
				  struct sock *sk)
{
	struct hci_request req;
	struct sk_buff *skb;
	int err = 0;

	bt_dev_dbg(hdev, "Opcode 0x%4.4x", opcode);

	hci_request_init(&req, hdev);

	hci_cmd_sync_add(&req, opcode, plen, param, event, sk);

	WRITE_ONCE(hdev->req_status, HCI_REQ_PEND);

	err = hci_req_sync_run(&req);
	if (err < 0)
		return ERR_PTR(err);

	err = wait_event_interruptible_timeout(hdev->req_wait_q,
					       READ_ONCE(hdev->req_status) != HCI_REQ_PEND,
					       timeout);

	if (err == -ERESTARTSYS)
		return ERR_PTR(-EINTR);

	switch (READ_ONCE(hdev->req_status)) {
	case HCI_REQ_DONE:
		err = -bt_to_errno(hdev->req_result);
		break;

	case HCI_REQ_CANCELED:
		err = -hdev->req_result;
		break;

	default:
		err = -ETIMEDOUT;
		break;
	}

	WRITE_ONCE(hdev->req_status, 0);
	hdev->req_result = 0;
	skb = hdev->req_rsp;
	hdev->req_rsp = NULL;

	bt_dev_dbg(hdev, "end: err %d", err);

	if (err < 0) {
		kfree_skb(skb);
		return ERR_PTR(err);
	}

	/* If command return a status event skb will be set to NULL as there are
	 * no parameters.
	 */
	if (!skb)
		return ERR_PTR(-ENODATA);

	return skb;
}
```
#### `net/bluetooth/hci_sync.c`: `hci_reset_sync` (from line 4005)
```c
int hci_reset_sync(struct hci_dev *hdev)
{
	set_bit(HCI_RESET, &hdev->flags);

	return __hci_cmd_sync_status(hdev, HCI_OP_RESET, 0, NULL,
				     HCI_CMD_TIMEOUT);
}
```
#### `net/bluetooth/lib.c`: `bt_to_errno` (from line 50)
```c
/**
 * bt_to_errno() - Bluetooth error codes to standard errno
 * @code: Bluetooth error code to be converted
 *
 * This function takes a Bluetooth error code as input and converts
 * it to an equivalent Unix/standard errno value.
 *
 * Return:
 *
 * If the bt error code is known, an equivalent Unix errno value
 * is returned.
 * If the given bt error code is not known, ENOSYS is returned.
 */
int bt_to_errno(__u16 code)
{
	switch (code) {
	case 0:
		return 0;

	case 0x01:
		return EBADRQC;

	case 0x02:
		return ENOTCONN;

	case 0x03:
		return EIO;

	case 0x04:
	case 0x3c:
		return EHOSTDOWN;

	case 0x05:
		return EACCES;

	case 0x06:
		return EBADE;

	case 0x07:
		return ENOMEM;

	case 0x08:
		return ETIMEDOUT;

	case 0x09:
		return EMLINK;

	case 0x0a:
		return EMLINK;

	case 0x0b:
		return EALREADY;

	case 0x0c:
		return EBUSY;

	case 0x0d:
	case 0x0e:
	case 0x0f:
		return ECONNREFUSED;

	case 0x10:
		return ETIMEDOUT;

	case 0x11:
	case 0x27:
	case 0x29:
	case 0x20:
		return EOPNOTSUPP;

	case 0x12:
		return EINVAL;

	case 0x13:
	case 0x14:
	case 0x15:
		return ECONNRESET;

	case 0x16:
		return ECONNABORTED;

	case 0x17:
		return ELOOP;

	case 0x18:
		return EACCES;

	case 0x1a:
		return EPROTONOSUPPORT;

	case 0x1b:
		return ECONNREFUSED;

	case 0x19:
	case 0x1e:
	case 0x23:
	case 0x24:
	case 0x25:
		return EPROTO;

	default:
		return ENOSYS;
	}
}
```
#### `net/bluetooth/mgmt.c`: `mgmt_errno_status` (from line 284)
```c
static u8 mgmt_errno_status(int err)
{
	switch (err) {
	case 0:
		return MGMT_STATUS_SUCCESS;
	case -EPERM:
		return MGMT_STATUS_REJECTED;
	case -EINVAL:
		return MGMT_STATUS_INVALID_PARAMS;
	case -EOPNOTSUPP:
		return MGMT_STATUS_NOT_SUPPORTED;
	case -EBUSY:
		return MGMT_STATUS_BUSY;
	case -ETIMEDOUT:
		return MGMT_STATUS_AUTH_FAILED;
	case -ENOMEM:
		return MGMT_STATUS_NO_RESOURCES;
	case -EISCONN:
		return MGMT_STATUS_ALREADY_CONNECTED;
	case -ENOTCONN:
		return MGMT_STATUS_DISCONNECTED;
	case -ECANCELED:
		return MGMT_STATUS_CANCELLED;
	case -ERFKILL:
		return MGMT_STATUS_RFKILLED;
	}

	return MGMT_STATUS_FAILED;
}
```
#### `net/bluetooth/mgmt.c`: `mgmt_status` (from line 314)
```c
static u8 mgmt_status(int err)
{
	if (err < 0)
		return mgmt_errno_status(err);

	if (err < ARRAY_SIZE(mgmt_status_table))
		return mgmt_status_table[err];

	return MGMT_STATUS_FAILED;
}
```
#### `drivers/usb/core/driver.c`: `usb_resume_interface` (from line 1337)
```c
static int usb_resume_interface(struct usb_device *udev,
		struct usb_interface *intf, pm_message_t msg, int reset_resume)
{
	struct usb_driver	*driver;
	int			status = 0;

	if (udev->state == USB_STATE_NOTATTACHED)
		goto done;

	/* Don't let autoresume interfere with unbinding */
	if (intf->condition == USB_INTERFACE_UNBINDING)
		goto done;

	/* Can't resume it if it doesn't have a driver. */
	if (intf->condition == USB_INTERFACE_UNBOUND) {

		/* Carry out a deferred switch to altsetting 0 */
		if (intf->needs_altsetting0 && !intf->dev.power.is_prepared) {
			usb_set_interface(udev, intf->altsetting[0].
					desc.bInterfaceNumber, 0);
			intf->needs_altsetting0 = 0;
		}
		goto done;
	}

	/* Don't resume if the interface is marked for rebinding */
	if (intf->needs_binding)
		goto done;
	driver = to_usb_driver(intf->dev.driver);

	if (reset_resume) {
		if (driver->reset_resume) {
			status = driver->reset_resume(intf);
			if (status)
				dev_err(&intf->dev, "%s error %d\n",
						"reset_resume", status);
		} else {
			intf->needs_binding = 1;
			dev_dbg(&intf->dev, "no reset_resume for driver %s?\n",
					driver->name);
		}
	} else {
		status = driver->resume(intf);
		if (status)
			dev_err(&intf->dev, "resume error %d\n", status);
	}

done:
	dev_vdbg(&intf->dev, "%s: status %d\n", __func__, status);

	/* Later we will unbind the driver and/or reprobe, if necessary */
	return status;
}
```
#### `drivers/usb/core/driver.c`: `usb_resume_both` (from line 1522)
```c
/**
 * usb_resume_both - resume a USB device and its interfaces
 * @udev: the usb_device to resume
 * @msg: Power Management message describing this state transition
 *
 * This is the central routine for resuming USB devices.  It calls the
 * resume method for @udev and then calls the resume methods for all
 * the interface drivers in @udev.
 *
 * Autoresume requests originating from a child device or an interface
 * driver may be made without the protection of @udev's device lock, but
 * all other resume calls will hold the lock.  Usbcore will insure that
 * method calls do not arrive during bind, unbind, or reset operations.
 * However drivers must be prepared to handle resume calls arriving at
 * unpredictable times.
 *
 * This routine can run only in process context.
 *
 * Return: 0 on success.
 */
static int usb_resume_both(struct usb_device *udev, pm_message_t msg)
{
	int			status = 0;
	int			i;
	struct usb_interface	*intf;
	bool			offload_active = false;

	if (udev->state == USB_STATE_NOTATTACHED) {
		status = -ENODEV;
		goto done;
	}
	udev->can_submit = 1;
	if (msg.event == PM_EVENT_RESUME)
		offload_active = usb_offload_check(udev);

	/* Resume the device */
	if (udev->state == USB_STATE_SUSPENDED || udev->reset_resume) {
		if (!offload_active)
			status = usb_resume_device(udev, msg);
		else
			dev_dbg(&udev->dev,
				"device offloaded, skip resume.\n");
	}

	/* Resume the interfaces */
	if (status == 0 && udev->actconfig) {
		for (i = 0; i < udev->actconfig->desc.bNumInterfaces; i++) {
			intf = udev->actconfig->interface[i];
			/*
			 * Interfaces with remote wakeup aren't suspended
			 * while the controller is active. This preserves
			 * pending interrupt urbs, allowing interrupt events
			 * to be handled during system suspend.
			 */
			if (offload_active && intf->needs_remote_wakeup) {
				dev_dbg(&intf->dev,
					"device offloaded, skip resume.\n");
				continue;
			}
			usb_resume_interface(udev, intf, msg,
					udev->reset_resume);
		}
	}
	usb_mark_last_busy(udev);

 done:
	dev_vdbg(&udev->dev, "%s: status %d\n", __func__, status);
	usb_offload_set_pm_locked(udev, false);
	if (!status)
		udev->reset_resume = 0;
	return status;
}
```
#### `drivers/usb/core/driver.c`: `usb_resume_complete` (from line 1646)
```c
/* The device lock is held by the PM core */
int usb_resume_complete(struct device *dev)
{
	struct usb_device *udev = to_usb_device(dev);

	/* For PM complete calls, all we do is rebind interfaces
	 * whose needs_binding flag is set
	 */
	if (udev->state != USB_STATE_NOTATTACHED)
		rebind_marked_interfaces(udev);
	return 0;
}
```
#### `drivers/usb/core/driver.c`: `unbind_marked_interfaces` (from line 1144)
```c
/*
 * Unbind drivers for @udev's marked interfaces.  These interfaces have
 * the needs_binding flag set, for example by usb_resume_interface().
 *
 * The caller must hold @udev's device lock.
 */
static void unbind_marked_interfaces(struct usb_device *udev)
{
	struct usb_host_config	*config;
	int			i;
	struct usb_interface	*intf;

	config = udev->actconfig;
	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			intf = config->interface[i];
			if (intf->dev.driver && intf->needs_binding)
				usb_forced_unbind_intf(intf);
		}
	}
}
```
#### `drivers/usb/core/driver.c`: `rebind_marked_interfaces` (from line 1191)
```c
/*
 * Rebind drivers to @udev's marked interfaces.  These interfaces have
 * the needs_binding flag set.
 *
 * The caller must hold @udev's device lock.
 */
static void rebind_marked_interfaces(struct usb_device *udev)
{
	struct usb_host_config	*config;
	int			i;
	struct usb_interface	*intf;

	config = udev->actconfig;
	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			intf = config->interface[i];
			if (intf->needs_binding)
				usb_rebind_intf(intf);
		}
	}
}
```
#### `drivers/usb/core/driver.c`: `autosuspend_check` (from line 1931)
```c
/* Internal routine to check whether we may autosuspend a device. */
static int autosuspend_check(struct usb_device *udev)
{
	int			w, i;
	struct usb_interface	*intf;

	if (udev->state == USB_STATE_NOTATTACHED)
		return -ENODEV;

	/* Fail if autosuspend is disabled, or any interfaces are in use, or
	 * any interface drivers require remote wakeup but it isn't available.
	 */
	w = 0;
	if (udev->actconfig) {
		for (i = 0; i < udev->actconfig->desc.bNumInterfaces; i++) {
			intf = udev->actconfig->interface[i];

			/* We don't need to check interfaces that are
			 * disabled for runtime PM.  Either they are unbound
			 * or else their drivers don't support autosuspend
			 * and so they are permanently active.
			 */
			if (intf->dev.power.disable_depth)
				continue;
			if (atomic_read(&intf->dev.power.usage_count) > 0)
				return -EBUSY;
			w |= intf->needs_remote_wakeup;

			/* Don't allow autosuspend if the device will need
			 * a reset-resume and any of its interface drivers
			 * doesn't include support or needs remote wakeup.
			 */
			if (udev->quirks & USB_QUIRK_RESET_RESUME) {
				struct usb_driver *driver;

				driver = to_usb_driver(intf->dev.driver);
				if (!driver->reset_resume ||
						intf->needs_remote_wakeup)
					return -EOPNOTSUPP;
			}
		}
	}
	if (w && !device_can_wakeup(&udev->dev)) {
		dev_dbg(&udev->dev, "remote wakeup needed for autosuspend\n");
		return -EOPNOTSUPP;
	}

	/*
	 * If the device is a direct child of the root hub and the HCD
	 * doesn't handle wakeup requests, don't allow autosuspend when
	 * wakeup is needed.
	 */
	if (w && udev->parent == udev->bus->root_hub &&
			bus_to_hcd(udev->bus)->cant_recv_wakeups) {
		dev_dbg(&udev->dev, "HCD doesn't handle wakeup requests\n");
		return -EOPNOTSUPP;
	}

	udev->do_remote_wakeup = w;
	return 0;
}
```
#### `drivers/usb/core/driver.c`: `usb_runtime_resume` (from line 2022)
```c
int usb_runtime_resume(struct device *dev)
{
	struct usb_device	*udev = to_usb_device(dev);
	int			status;

	/* Runtime resume for a USB device means resuming both the device
	 * and all its interfaces.
	 */
	status = usb_resume_both(udev, PMSG_AUTO_RESUME);
	return status;
}
```
#### `drivers/usb/core/hub.c`: `finish_port_resume` (from line 3638)
```c
/*
 * If the USB "suspend" state is in use (rather than "global suspend"),
 * many devices will be individually taken out of suspend state using
 * special "resume" signaling.  This routine kicks in shortly after
 * hardware resume signaling is finished, either because of selective
 * resume (by host) or remote wakeup (by device) ... now see what changed
 * in the tree that's rooted at this device.
 *
 * If @udev->reset_resume is set then the device is reset before the
 * status check is done.
 */
static int finish_port_resume(struct usb_device *udev)
{
	int	status = 0;
	u16	devstatus = 0;

	/* caller owns the udev device lock */
	dev_dbg(&udev->dev, "%s\n",
		udev->reset_resume ? "finish reset-resume" : "finish resume");

	/* usb ch9 identifies four variants of SUSPENDED, based on what
	 * state the device resumes to.  Linux currently won't see the
	 * first two on the host side; they'd be inside hub_port_init()
	 * during many timeouts, but hub_wq can't suspend until later.
	 */
	usb_set_device_state(udev, udev->actconfig
			? USB_STATE_CONFIGURED
			: USB_STATE_ADDRESS);

	/* 10.5.4.5 says not to reset a suspended port if the attached
	 * device is enabled for remote wakeup.  Hence the reset
	 * operation is carried out here, after the port has been
	 * resumed.
	 */
	if (udev->reset_resume) {
		/*
		 * If the device morphs or switches modes when it is reset,
		 * we don't want to perform a reset-resume.  We'll fail the
		 * resume, which will cause a logical disconnect, and then
		 * the device will be rediscovered.
		 */
 retry_reset_resume:
		if (udev->quirks & USB_QUIRK_RESET)
			status = -ENODEV;
		else
			status = usb_reset_and_verify_device(udev);
	}

	/* 10.5.4.5 says be sure devices in the tree are still there.
	 * For now let's assume the device didn't go crazy on resume,
	 * and device drivers will know about any resume quirks.
	 */
	if (status == 0) {
		devstatus = 0;
		status = usb_get_std_status(udev, USB_RECIP_DEVICE, 0, &devstatus);

		/* If a normal resume failed, try doing a reset-resume */
		if (status && !udev->reset_resume && udev->persist_enabled) {
			dev_dbg(&udev->dev, "retry with reset-resume\n");
			udev->reset_resume = 1;
			goto retry_reset_resume;
		}
	}

	if (status) {
		dev_dbg(&udev->dev, "gone after usb resume? status %d\n",
				status);
	/*
	 * There are a few quirky devices which violate the standard
	 * by claiming to have remote wakeup enabled after a reset,
	 * which crash if the feature is cleared, hence check for
	 * udev->reset_resume
	 */
	} else if (udev->actconfig && !udev->reset_resume) {
		if (udev->speed < USB_SPEED_SUPER) {
			if (devstatus & (1 << USB_DEVICE_REMOTE_WAKEUP))
				status = usb_disable_remote_wakeup(udev);
		} else {
			status = usb_get_std_status(udev, USB_RECIP_INTERFACE, 0,
					&devstatus);
			if (!status && devstatus & (USB_INTRF_STAT_FUNC_RW_CAP
					| USB_INTRF_STAT_FUNC_RW))
				status = usb_disable_remote_wakeup(udev);
		}

		if (status)
			dev_dbg(&udev->dev,
				"disable remote wakeup, status %d\n",
				status);
		status = 0;
	}
	return status;
}
```
#### `drivers/usb/core/hub.c`: `usb_reset_device` (from line 6341)
```c
/**
 * usb_reset_device - warn interface drivers and perform a USB port reset
 * @udev: device to reset (not in NOTATTACHED state)
 *
 * Warns all drivers bound to registered interfaces (using their pre_reset
 * method), performs the port reset, and then lets the drivers know that
 * the reset is over (using their post_reset method).
 *
 * Return: The same as for usb_reset_and_verify_device().
 * However, if a reset is already in progress (for instance, if a
 * driver doesn't have pre_reset() or post_reset() callbacks, and while
 * being unbound or re-bound during the ongoing reset its disconnect()
 * or probe() routine tries to perform a second, nested reset), the
 * routine returns -EINPROGRESS.
 *
 * Note:
 * The caller must own the device lock.  For example, it's safe to use
 * this from a driver probe() routine after downloading new firmware.
 * For calls that might not occur during probe(), drivers should lock
 * the device using usb_lock_device_for_reset().
 *
 * If an interface is currently being probed or disconnected, we assume
 * its driver knows how to handle resets.  For all other interfaces,
 * if the driver doesn't have pre_reset and post_reset methods then
 * we attempt to unbind it and rebind afterward.
 */
int usb_reset_device(struct usb_device *udev)
{
	int ret;
	int i;
	unsigned int noio_flag;
	struct usb_port *port_dev;
	struct usb_host_config *config = udev->actconfig;
	struct usb_hub *hub = usb_hub_to_struct_hub(udev->parent);

	if (udev->state == USB_STATE_NOTATTACHED) {
		dev_dbg(&udev->dev, "device reset not allowed in state %d\n",
				udev->state);
		return -EINVAL;
	}

	if (!udev->parent) {
		/* this requires hcd-specific logic; see ohci_restart() */
		dev_dbg(&udev->dev, "%s for root hub!\n", __func__);
		return -EISDIR;
	}

	if (udev->reset_in_progress)
		return -EINPROGRESS;
	udev->reset_in_progress = 1;

	port_dev = hub->ports[udev->portnum - 1];

	/*
	 * Don't allocate memory with GFP_KERNEL in current
	 * context to avoid possible deadlock if usb mass
	 * storage interface or usbnet interface(iSCSI case)
	 * is included in current configuration. The easist
	 * approach is to do it for every device reset,
	 * because the device 'memalloc_noio' flag may have
	 * not been set before reseting the usb device.
	 */
	noio_flag = memalloc_noio_save();

	/* Prevent autosuspend during the reset */
	usb_autoresume_device(udev);

	if (config) {
		for (i = 0; i < config->desc.bNumInterfaces; ++i) {
			struct usb_interface *cintf = config->interface[i];
			struct usb_driver *drv;
			int unbind = 0;

			if (cintf->dev.driver) {
				drv = to_usb_driver(cintf->dev.driver);
				if (drv->pre_reset && drv->post_reset)
					unbind = (drv->pre_reset)(cintf);
				else if (cintf->condition ==
						USB_INTERFACE_BOUND)
					unbind = 1;
				if (unbind)
					usb_forced_unbind_intf(cintf);
			}
		}
	}

	usb_lock_port(port_dev);
	ret = usb_reset_and_verify_device(udev);
	usb_unlock_port(port_dev);

	if (config) {
		for (i = config->desc.bNumInterfaces - 1; i >= 0; --i) {
			struct usb_interface *cintf = config->interface[i];
			struct usb_driver *drv;
			int rebind = cintf->needs_binding;

			if (!rebind && cintf->dev.driver) {
				drv = to_usb_driver(cintf->dev.driver);
				if (drv->post_reset)
					rebind = (drv->post_reset)(cintf);
				else if (cintf->condition ==
						USB_INTERFACE_BOUND)
					rebind = 1;
				if (rebind)
					cintf->needs_binding = 1;
			}
		}

		/* If the reset failed, hub_wq will unbind drivers later */
		if (ret == 0)
			usb_unbind_and_rebind_marked_interfaces(udev);
	}

	usb_autosuspend_device(udev);
	memalloc_noio_restore(noio_flag);
	udev->reset_in_progress = 0;
	return ret;
}
```
#### `drivers/usb/core/hub.c`: `usb_queue_reset_device` (from line 6462)
```c
/**
 * usb_queue_reset_device - Reset a USB device from an atomic context
 * @iface: USB interface belonging to the device to reset
 *
 * This function can be used to reset a USB device from an atomic
 * context, where usb_reset_device() won't work (as it blocks).
 *
 * Doing a reset via this method is functionally equivalent to calling
 * usb_reset_device(), except for the fact that it is delayed to a
 * workqueue. This means that any drivers bound to other interfaces
 * might be unbound, as well as users from usbfs in user space.
 *
 * Corner cases:
 *
 * - Scheduling two resets at the same time from two different drivers
 *   attached to two different interfaces of the same device is
 *   possible; depending on how the driver attached to each interface
 *   handles ->pre_reset(), the second reset might happen or not.
 *
 * - If the reset is delayed so long that the interface is unbound from
 *   its driver, the reset will be skipped.
 *
 * - This function can be called during .probe().  It can also be called
 *   during .disconnect(), but doing so is pointless because the reset
 *   will not occur.  If you really want to reset the device during
 *   .disconnect(), call usb_reset_device() directly -- but watch out
 *   for nested unbinding issues!
 */
void usb_queue_reset_device(struct usb_interface *iface)
{
	if (schedule_work(&iface->reset_ws))
		usb_get_intf(iface);
}
```
#### `drivers/usb/core/message.c`: `__usb_queue_reset_device` (from line 1958)
```c
/*
 * Internal function to queue a device reset
 * See usb_queue_reset_device() for more details
 */
static void __usb_queue_reset_device(struct work_struct *ws)
{
	int rc;
	struct usb_interface *iface =
		container_of(ws, struct usb_interface, reset_ws);
	struct usb_device *udev = interface_to_usbdev(iface);

	rc = usb_lock_device_for_reset(udev, iface);
	if (rc >= 0) {
		usb_reset_device(udev);
		usb_unlock_device(udev);
	}
	usb_put_intf(iface);	/* Undo _get_ in usb_queue_reset_device() */
}
```
#### `drivers/usb/core/usb.c`: `usb_lock_device_for_reset` (from line 881)
```c
/**
 * usb_lock_device_for_reset - cautiously acquire the lock for a usb device structure
 * @udev: device that's being locked
 * @iface: interface bound to the driver making the request (optional)
 *
 * Attempts to acquire the device lock, but fails if the device is
 * NOTATTACHED or SUSPENDED, or if iface is specified and the interface
 * is neither BINDING nor BOUND.  Rather than sleeping to wait for the
 * lock, the routine polls repeatedly.  This is to prevent deadlock with
 * disconnect; in some drivers (such as usb-storage) the disconnect()
 * or suspend() method will block waiting for a device reset to complete.
 *
 * Return: A negative error code for failure, otherwise 0.
 */
int usb_lock_device_for_reset(struct usb_device *udev,
			      const struct usb_interface *iface)
{
	unsigned long jiffies_expire = jiffies + HZ;

	if (udev->state == USB_STATE_NOTATTACHED)
		return -ENODEV;
	if (udev->state == USB_STATE_SUSPENDED)
		return -EHOSTUNREACH;
	if (iface && (iface->condition == USB_INTERFACE_UNBINDING ||
			iface->condition == USB_INTERFACE_UNBOUND))
		return -EINTR;

	while (!usb_trylock_device(udev)) {

		/* If we can't acquire the lock after waiting one second,
		 * we're probably deadlocked */
		if (time_after(jiffies, jiffies_expire))
			return -EBUSY;

		msleep(15);
		if (udev->state == USB_STATE_NOTATTACHED)
			return -ENODEV;
		if (udev->state == USB_STATE_SUSPENDED)
			return -EHOSTUNREACH;
		if (iface && (iface->condition == USB_INTERFACE_UNBINDING ||
				iface->condition == USB_INTERFACE_UNBOUND))
			return -EINTR;
	}
	return 0;
}
```
#### `drivers/usb/core/urb.c`: `usb_anchor_urb` (from line 118)
```c
/**
 * usb_anchor_urb - anchors an URB while it is processed
 * @urb: pointer to the urb to anchor
 * @anchor: pointer to the anchor
 *
 * This can be called to have access to URBs which are to be executed
 * without bothering to track them
 */
void usb_anchor_urb(struct urb *urb, struct usb_anchor *anchor)
{
	unsigned long flags;

	spin_lock_irqsave(&anchor->lock, flags);
	usb_get_urb(urb);
	list_add_tail(&urb->anchor_list, &anchor->urb_list);
	urb->anchor = anchor;

	if (unlikely(anchor->poisoned))
		atomic_inc(&urb->reject);

	spin_unlock_irqrestore(&anchor->lock, flags);
}
```
#### `drivers/usb/core/urb.c`: `usb_scuttle_anchored_urbs` (from line 989)
```c
/**
 * usb_scuttle_anchored_urbs - unanchor all an anchor's urbs
 * @anchor: the anchor whose urbs you want to unanchor
 *
 * use this to get rid of all an anchor's urbs
 */
void usb_scuttle_anchored_urbs(struct usb_anchor *anchor)
{
	struct urb *victim;
	unsigned long flags;
	int surely_empty;

	do {
		spin_lock_irqsave(&anchor->lock, flags);
		while (!list_empty(&anchor->urb_list)) {
			victim = list_entry(anchor->urb_list.prev,
					    struct urb, anchor_list);
			__usb_unanchor_urb(victim, anchor);
		}
		surely_empty = usb_anchor_check_wakeup(anchor);

		spin_unlock_irqrestore(&anchor->lock, flags);
		cpu_relax();
	} while (!surely_empty);
}
```
#### `include/linux/pm_runtime.h`: `pm_runtime_active` (from line 155)
```c
/**
 * pm_runtime_active - Check whether or not a device is runtime-active.
 * @dev: Target device.
 *
 * Note that the return value of this function can only be trusted if it is
 * called under the runtime PM lock of @dev or under conditions in which
 * runtime PM cannot be either disabled or enabled for @dev and its runtime PM
 * status cannot change.
 *
 * Return:
 * * %true: Runtime PM is disabled for @dev or its status is %RPM_ACTIVE.
 * * %false: Otherwise.
 */
static inline bool pm_runtime_active(struct device *dev)
{
	return dev->power.runtime_status == RPM_ACTIVE
		|| dev->power.disable_depth;
}
```

## 9. The defects (issue register, BT-17 to BT-24)
*(verbatim: `docs/issues.md`, from BT-17 to the end of BT-24)*
### BT-17 — With the patch loaded, an idle controller ignored its next command, was reset off the USB bus, and stayed off until a power-off

**Status 2026-11-12: observed once (boot `08956069`, 2026-11-12 18:03); cause not established.**
Evidence, with every command and its output: [`results/incident-2026-11-12-1803/`](../results/incident-2026-11-12-1803/README.md). That directory has eight focused log excerpts (kernel, userspace, HCI capture decode; addresses replaced). The full journals of the three boots (text and export format) and every capture are kept locally in the git-ignored `archive/incidents/20261112-bt17-controller-off-bus/` (with `SHA256SUMS`).

- **What:** boot `08956069`, `7.0.0-42` with E3, the first boot after a 7.5 min power-off.
  - Start-up was normal (`QCA: patch rome 0x302 build 0x3e8`, no start-up disconnect), so this is **not BT-16**.
  - The controller then sat idle for 161.98 s, with no ACL or SCO link.
  - At the operator's login (18:03:08) bluetoothd removed the greeter's profile UUIDs. The kernel's `Write Class of Device` (`0x0c24`) got **no event of any kind** (capture: last event #120 at 18:00:26.845).
  - `command 0x0c24 tx timeout` at 18:03:10.87.
  - USB resets from 18:03:14.12 failed with `-71`, and the device disconnected at 18:03:16.18. Re-enumeration failed, ending in `unable to enumerate USB device` (18:03:19).
  - The 18:07 **reboot** did not bring it back: in boot `b314ca88` the device is not on the bus (`error -71` at enumeration), while the card's Wi-Fi works.
- **Like BT-1 in shape, unlike it in conditions.** As in BT-1, the first command after a change got no reply, the controller left the bus after a reset, and only a power-off recovers it (BRIEF §0). Unlike BT-1:
  - the patch was loaded (BT-1's cause was the ROM firmware, fixed by `dc16388d45ec`);
  - no SCO stream existed;
  - the change was 162 s of idle.

  It is the first timeout in nine E3 trials and 74 E1/E3 links (`evidence/trials/results.tsv`, E3 #9). So the device-table fix does not cover it, and it gets its own row.
- **The reset path (source, Ubuntu `7.0.0-42`):**
  - `hci_cmd_timeout()` calls `hdev->reset` on the **first** timeout (`net/bluetooth/hci_core.c:1477`).
  - `BTUSB_QCA_ROME` sets `hdev->reset = btusb_qca_reset` (`drivers/bluetooth/btusb.c:4406`).
  - Without a reset GPIO that becomes `btusb_reset()`: `usb_queue_reset_device()` (`btusb.c:1034-1051`).
  - `Failed usb_autopm_get_interface: -16` at 18:03:16.18 shows the path was entered.
  - **Not established:** what issued the first USB reset at 18:03:14.12. `Resetting usb device.` is not in the journal.
  - If it was the kernel's own reset, the same entry that fixed BT-1 also makes the kernel apply, automatically, the action that drove a wedged controller here off the bus in two controlled tests (`EX-023`, the 2026-08-15 boot). That is an inference to test, not a finding.
- **Candidates (not traced, not rows):**
  1. Whether runtime autosuspend was involved. `CONFIG_BT_HCIBTUSB_AUTOSUSPEND=y` and no override is installed (`/etc/modprobe.d/btusb-qca9377.conf.disabled`). The 162 s idle and the first command after it fit a failed resume, but btusb debug output was off, so no record shows whether the device was suspended. The earlier "autosuspend mitigation" claim for BT-1 is retracted (BRIEF §5); that retraction is about ROM firmware and does not decide this case.
  2. The reset-on-first-timeout policy for ROME controllers without a reset GPIO.
  3. The kernel's mgmt status `0x05` "Authentication Failed" for a command that timed out (`-ETIMEDOUT` mapping; check in source).
  4. *This project's trial tool:* `usb_lost` counts every USB disconnect on the machine (E3 #6: 82, all on ports `3-2`/`4-2`, none on `3-3`).
- **Falsifiers / next:**
  - Recurrence on `7.0.0-43` (its stock btusb carries the entry; E3 is not used there).
  - Whether a recurrence follows an idle period again.
  - Whether `power/runtime_status` of the controller's USB device reads `suspended` during idle (a sysfs read, safe).
  - Whether the first reset carries `Resetting usb device.` with btusb debug on.
- **Recovery:** full power-off. **Reportable:** not yet; one occurrence.
- **2026-11-12 22:57, after the power-off** (boot `46cc4812`, `7.0.0-43`, stock btusb, off ~8.4 min since 22:46:44):
  - The controller is back: `QCA: patch rome 0x302 build 0x3e8`, `hci0`, bluetoothd `Number of controllers: 1`.
  - The loaded btusb srcversion is `4B2BD2C14BA4918C28E7208`, equal to `modinfo -F srcversion` of `-43`'s stock `btusb.ko.zst`, and there is no out-of-tree taint line.
  - **The idle controller is runtime-suspended.** `/sys/bus/usb/devices/3-3/power/`: `control auto`, `autosuspend_delay_ms 2000`, `runtime_status suspended`, `runtime_suspended_time 145431` of ~158,500 ms.
  - So every idle period suspends it, and the first command after one resumes it. That fits candidate 1 and is not proof: the same was presumably true on every earlier E3 boot (same Kconfig, no override). Next: whether a recurrence again follows a suspend, which needs btusb debug or a runtime-PM trace.
- **2026-11-13, read from the archived full kernel log (btusb debug was on, from `bt-dyndbg`; the earlier "debug off" line above is wrong):**
  - **The controller was runtime-suspended when the command was sent, and it never resumed.** btusb's `intf %p` prints (`btusb_suspend()`/`btusb_resume()`) show a device suspend at 18:00:28.857, 2.011 s after the last answer, and no `btusb_resume()` before the disconnect at 18:03:16. Monotonic times: suspended 160.83 s; command sent at 178.731; first USB reset at 184.023, 5.291 s later.
  - Excerpts: `results/incident-2026-11-12-1803/excerpt-boot-1-btusb-suspend-cycles.txt` and `excerpt-boot-2-btusb-suspend-cycles.txt`, written by `tools/suspend-cycles.py`. The boot before (`7e87eae0`, same setup) resumed 8 times, including after suspends of 2,950 s and 4,250 s.
  - **Source reading (hypotheses, not findings):**
    - H1: the first reset is the USB core's reset-resume. `finish_port_resume()` retries a failed post-resume GET_STATUS (5,000 ms timeout) as a reset-resume, since `persist` is 1. That would explain why btusb's `Resetting usb device.` (`bt_dev_err`) never appears.
    - H2: `hci_cmd_timeout()` → `btusb_reset()` waited 5.3 s in `usb_autopm_get_interface()` behind that resume, then got `-EBUSY` (`rpm_resume()`'s parent check), so the command credit came back only at 186.083.
  - **Candidate H3:** mainline `dcaf83ead130` sets `BTUSB_WAKEUP_BROKEN` (no runtime suspend with remote wakeup armed) for MT7922/MT7925 on Ryzen root hubs. It describes the same symptom: unresponsive, resetting the root hub does not help, only a power cycle recovers. This laptop is a Ryzen 7 5825U, and the controller is a direct child of the SoC root hub (`1022:1639`). It is not traced as ours yet.
  - `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED` (`mgmt.c:299`): candidate 3 is confirmed in source.
  - Outside source review requested: `reviews/2026-11-13T0003Z-bt17-source-investigation-task.md`.
- **2026-11-13, the outside reviews** (five answers, `reviews/2026-11-13T02*`–`T04*-bt17-source-investigation-reviewer-*-verbatim.md`, each with our checks in its header):
  - **H2 holds**, by all five. The log alone proves it: no `cmd_cnt` line between 18:03:08.8 and 18:03:16.2 although three commands were queued on the ordered HCI workqueue (sixth review).
  - **H1 is the best fit**, by all five. With the xHCI driver's own 40 ms resume drive and the port reset (60 ms) and its recovery (50 ms) that precede the `reset full-speed` line, the fixed waits come to 5,200 ms of the 5,291 ms; about 91 ms is left for scheduling. Open: who started the resume (host or a remote wakeup), and which branch issued the reset.
  - **H3 is a candidate for an A/B test, not a finding**, by all five.
  - **Corrections to our brief:**
    - frame #122 never reached the hardware: `BTUSB_SUSPENDING` was still set, so btusb parked it on the deferred anchor;
    - the capture proves only core send attempts (the monitor copy precedes the `HCI_RUNNING` test);
    - a missing `btusb_resume()` print alone does not prove a failed resume; the failed reset-resume and the disconnect do.
  - **New, verified:** a queued xHCI fix matches the tail of our log (BT-22).
- **2026-11-13, reproduced in emulation** (`results/bt17-emulation-2026-11-13/`):
  - Setup: real btusb (bluetooth-next `da3cc0258`) in a QEMU guest, bound through usbip to an emulated `13d3:3503` (QCA ROME path, full speed, remote wakeup). It stops answering at a chosen resume: GET_STATUS held, then `-71` after the host gives up.
  - **The laptop's sequence comes out step by step, with the USB core debug lines the laptop lacked:**
    - `usb auto-resume`, `finish resume`, `tx timeout` at +2.05 s;
    - MGMT status `0x05` for the class write;
    - `retry with reset-resume`, first `reset full-speed` at +5.38 s (laptop: +5.29 s);
    - four resets, `gone after usb resume?`, `USB disconnect` at +7.43 s (laptop: +7.35 s);
    - `Failed usb_autopm_get_interface: -16` 2 ms later; no `Resetting usb device.`
  - So H1 and H2 hold for this kernel's code when a device stops answering after a host-initiated runtime resume. What made the real controller stop answering is not addressed by this; it needs a recurrence on the laptop.
  - **Found with it:** BT-18, BT-19, BT-20 (btusb) and BT-21 (MGMT); BT-23 reproduced with a widened window; patch candidates in CO-43 (five) and CO-44.

---

### BT-18 — After a successful runtime reset-resume, btusb is never resumed and Bluetooth stays dead

**Status 2026-11-13: reproduced in emulation; fix candidate CO-43 D; not seen on the laptop (there the reset-resume failed).**
- **What:** when a runtime resume fails and USB persist is on, the USB core resets the device. btusb has no `reset_resume` callback, so `usb_resume_interface()` only marks its interfaces for rebinding (`no reset_resume for driver btusb?`). The core rebinds marked interfaces only after a system resume (`usb_resume_complete()`) or a `usb_reset_device()`, not after a runtime resume (`drivers/usb/core/driver.c`, bluetooth-next `da3cc0258`).
- **Effect:** btusb stays bound and is never resumed. `BTUSB_SUSPENDING` stays set and the suspend count is off by one, so every URB is parked on the deferred anchor. The controller answers USB requests, yet Bluetooth is dead until unplug or reboot.
- **Reproduced** (`close-recover` scenario):
  - the resume is started by powering hci0 off (`btusb_close()` takes a PM reference), the device answers again after the reset-resume;
  - the next power-on fails: HCI Reset `0x0c03` `-110` twice, never sent, MGMT status `0x05`;
  - when the resume is started by a command instead, btusb's own reset from the command timeout rebinds it by accident (BT-19).
- **Fix candidate:** CO-43 D, a `reset_resume` that resumes and queues a reset, so the core rebinds btusb and the controller is set up again.
- **D is not to be sent as a fix (outside reviews, 2026-11-13).**
  - **It lets more devices autosuspend:** it opens `autosuspend_check()`'s gate for devices with the reset-resume quirk.
  - **It restarts traffic before the rebinding.**
  - **It still costs two resets.**
  - **Its queued reset can be lost.** The reset work does nothing if `usb_lock_device_for_reset()` fails, for example because the device has autosuspended meanwhile, and D holds no PM reference. And with the callback present, the core no longer marks the interface for rebinding.
  - **Next:** the question goes to linux-usb as a USB core one first, with D as the btusb fallback (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`).

### BT-19 — `btusb_reset()` blocks the HCI workqueue behind a failing resume, and resets a reset-resumed device again

**Status 2026-11-13: in the laptop's log (H2) and reproduced in emulation; fix candidate CO-43 B.**
- **What:**
  - `hci_cmd_timeout()` calls `hdev->reset` on the ordered `hdev->workqueue` before it restores the credit. `btusb_reset()` first calls `usb_autopm_get_interface()`, which waits for the resume in progress.
  - The command that timed out never reached the controller (still on the deferred anchor).
- **Effect:**
  - the HCI workqueue (cmd, RX, TX work) is blocked 5.3 s on the laptop, 5.4 s in emulation;
  - when the reset-resume succeeds, the waiting reset then resets the device once more (`Resetting usb device.` after the rebinding).
- **Fix candidate:** CO-43 B. Don't reset while `BTUSB_SUSPENDING` is set and the interface is not runtime-active; if it is active although btusb was not resumed (BT-18 without D), reset as before.
- **B is on hold (outside reviews, 2026-11-13).**
  - **Its exception never fires:** our own `ab-recover-1.log` shows it.
  - **It can skip a needed reset.** `tx_in_flight` drops when the USB transfer completes, not at the HCI answer. So a controller can get a command, never answer it, and autosuspend before the timeout fires. B then skips its reset. In BT-17 the command never left; that is not true of every case B's test admits.
  - **The rewrite** waits for the BT-18 decision, and it must tell a deferred command from one that was sent.
  - **Shown in emulation (`dropcmd-wedge`, `results/bt17-emulation-2026-11-13/`).** A controller that got the command and stays silent until a USB reset:
    - recovers unpatched, 3/3;
    - stays dead with B, 6/6, and also after a 60 s settle.

    The power cycle's HCI Resets cannot trigger another reset, because the command timer is not armed while `HCI_RESET` is set (`hci_core.c:4351-4353`).

### BT-20 — `btusb_waker()` swallows a failed resume

**Status 2026-11-13: in source; shown in emulation; fix candidate CO-43 A.**
- **What:** the waker returns on a failed `usb_autopm_get_interface()` without a message (bluetooth-next `btusb_main.c:2656`, from `7bee549e197c`, 2009). At the default log level the only trace of a failed resume is the HCI timeout two seconds later, which points at the controller.
- **Fix candidate:** CO-43 A, log the error (except `-EACCES`, a system sleep transition).

### BT-21 — MGMT reports a command timeout as "Authentication Failed"

**Status 2026-11-13: in the laptop's log (bluetoothd: "Failed to remove UUID: Authentication Failed (0x05)") and reproduced; fix candidate CO-44.**
- **What:** `mgmt_errno_status()` maps `-ETIMEDOUT` to `MGMT_STATUS_AUTH_FAILED`, since `161510ccf91c` (2021-10-27), with no stated reason. `MGMT_STATUS_TIMEOUT` (0x08) exists.
- **Reproduced:** a new mgmt-tester case, whose emulated controller never answers Write Class of Device, fails on bluetooth-next with 0x05 and passes with the one-line fix. The other 526 mgmt-tester cases, l2cap-tester (144) and smp-tester (8) are unchanged (`agent-work/bt17-mgmt-timeout/`, logs with SHA256SUMS).
- **Audit:** pairing paths use the HCI status table, not this function, so they are unaffected. bluetoothd only logs the text for the sync-queued commands; nothing in BlueZ depends on 0x05 for a timeout.

### BT-22 — xHCI: ep0 maxpacket update on a slot left Enabled (another author's fix, queued)

**Status 2026-11-13: in the laptop's log (the BT-17 tail); fixed by another author, queued by the xHCI maintainer on 2026-11-09; not ours.**
- **What:** after an Address Device transaction error the slot is left Enabled. `xhci_check_ep0_maxpacket()` then issues Evaluate Context on it (`WARN: invalid context state for evaluate context command`, harmless) and corrupts the input context, so the next Address Device is refused with Parameter Error (`completion code 0x11`).
- **The fix:** "[PATCH] usb: xhci: Fix ep0 maxpacket update on enabled slots", Michal Pecio, 2026-11-09, `<20261109112846.04bfeb0f.michal.pecio@gmail.com>`; "Added to queue" by Mathias Nyman the same day.
- **On the laptop:** the code it fixes is in v7.0 and in Ubuntu's `-42` (no hunk there). Our log has the sequence for the full-speed device at 18:03:15.65–15.97. It made the reset retries fail in a messier way; it did not cause the loss: the device had already failed a descriptor read, and the next boot's fresh xHCI could not read it either.
- **Next:** watch for it in mainline and stable; an Ubuntu backport candidate.

### BT-23 — btusb: a URB can be parked on the deferred anchor after the resume that would send it

**Status 2026-11-13: race from source (seventh review), reproduced in emulation with the window widened by a debug-only delay; fix candidate CO-43 E; not BT-17.**
- **Reproduced:** `bt23` scenario, with a 400 ms delay after the decision (debug-only module parameter) and a resume forced meanwhile (`power/control=on`):
  - unpatched: btusb's resume ran, the command was parked after it, and the class write timed out after 2.02 s with MGMT 0x05, 3 of 3;
  - with E: answered after the 0.40 s delay, 2 of 2;
  - 20 healthy cycles on the E kernel: 20 of 20, latency unchanged.
- Without the delay the window is a few instructions wide. How often it occurs on real hardware is unknown.
- **What:** `submit_or_queue_tx_urb()` reads `BTUSB_SUSPENDING` under `txlock`, releases the lock, and only then anchors the URB on `deferred`. `btusb_resume()` drains `deferred` and clears the flag under `txlock`. A resume completing in between leaves the URB parked while the device is active, until the next suspend/resume cycle.
- **Fix candidate:** CO-43 E, "Bluetooth: btusb: Anchor a deferred URB under txlock": the anchoring moves into the decision's critical section. The lock order is unchanged: `btusb_resume()` already takes the anchor's lock inside `txlock`.

### BT-24 — btusb: a URB deferred during a failed resume is parked after the scuttle

**Status 2026-11-13: race from source (an outside review of the CO-43 patches, reviewer 7); not reproduced; no fix yet; not BT-17.**
- **What:** on its `failed:` path (an interrupt or bulk URB could not be submitted), `btusb_resume()` (bluetooth-next `da3cc0258`, `btusb_main.c:5075-5080`):
  - calls `usb_scuttle_anchored_urbs(&data->deferred)` without `txlock`;
  - then clears `BTUSB_SUSPENDING` under `txlock`.

  A sender that takes `txlock` in between still sees the flag and anchors its URB on `deferred`. Nothing sends it until the next resume, and an HCI command in it times out.
- **Relation to BT-23:** the same kind of window, on the failure path. CO-43 E closes BT-23's window (successful resume) but not this one.
- **Next:** an emulator test, a deferred send racing a failed receive-URB submission at resume (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`, finding 17). Then the fix: scuttle under `txlock`, or clear the flag first. The scuttle frees URBs, so which of the two fits is to be decided.

## 10. The dossiers
*(verbatim: `contributions/CO-43-btusb-runtime-resume-failure/README.md`)*
### CO-43 — btusb: a device that fails, or needs a reset, to resume (BT-18, BT-19, BT-20; BT-17)

**Where it comes from:** BT-17 (2026-11-12 18:03). The laptop's idle QCA9377 (`13d3:3503`)
was runtime-suspended, and the next command started a resume that the device never answered.
The outside reviews (`reviews/2026-11-13T02*`–`T04*-bt17-*`) agree on how the kernel then
behaved. An emulation reproduces it step by step and found three btusb defects on the way
(`results/bt17-emulation-2026-11-13/`):

- **BT-20:** `btusb_waker()` swallows the failed resume.
- **BT-19:** `btusb_reset()`, called by the command timeout:
  - blocks the ordered HCI workqueue behind the failing resume (5.3 s on the laptop, 5.4 s in
    emulation);
  - when the reset-resume succeeds, resets the device a second time.
- **BT-18:** after a *successful* runtime reset-resume, btusb is never resumed: no
  `reset_resume` callback, and the USB core does not rebind after a runtime resume. Bluetooth
  stays dead with a healthy device.

None of the three made the controller stop answering. That cause (firmware, platform power,
or the AMD host) is not addressed by any patch here and needs a recurrence on the laptop with
USB core debug.

**State (2026-11-13): five patches written on bluetooth-next `da3cc0258` and tested in
emulation; nothing sent.** Patches in `patch/`, in this order, without Signed-off-by (the
operator adds his own). checkpatch `--strict --no-tree` reports only the missing Signed-off-by,
plus on patch 5 an unknown commit id (no tree) and two CamelCase notes for the USB core's own
`idVendor`/`idProduct`.

| # | subject | fixes | for upstream? |
|---|---|---|---|
| 1 (A) | Bluetooth: btusb: Report a failed resume for deferred data | BT-20 | yes, small |
| 2 (B) | Bluetooth: btusb: Don't reset a device that has not resumed | BT-19 | yes |
| 3 (D) | Bluetooth: btusb: Recover after a reset-resume | BT-18 | yes, after a system-suspend test |
| 4 (E) | Bluetooth: btusb: Anchor a deferred URB under txlock | BT-23 | yes, small |
| 5 (C) | Bluetooth: btusb: Disable runtime suspend of QCA9377 13d3:3503 on Ryzen | BT-17 H3 | **RFC only**: one occurrence |

**Measured** (QEMU, 4 CPUs, KASAN and lockdep; the emulated device fails at its first resume;
`results/bt17-emulation-2026-11-13/README.md`, "Results"): see that table. In short:
- **unpatched:**
  - dead device: the laptop's sequence;
  - recovering device: back only through `btusb_reset()`'s second reset (BT-19);
  - power-off-started resume: Bluetooth dead, 5 of 5;
- **A+B+D:**
  - dead device: no stall, no reset, the failed resume logged;
  - recovering device: back, 5 of 5;
  - power-off-started resume: back, 5 of 5;
  - healthy cycles unchanged;
- **C** on a guest that sees the laptop's Ryzen CPU: the device no longer suspends while
  hci0 is up, so the fault does not occur; on a non-Ryzen guest C changes nothing.
- **E**, with a debug-only delay that widens BT-23's window and a resume forced inside it:
  - unpatched: parked and timed out, 3 of 3;
  - with E: answered, 2 of 2.

**Ubuntu:** all five apply, in order, to Ubuntu `7.0.0-42`'s single `drivers/bluetooth/btusb.c`
with line offsets only (`tmp/bt17-review/ubuntu-port-check.sh`, a dry run on a copy). A test
module for the laptop's `-43` would need `-43`'s btusb source and the operator's word to install.

**The list's CI bot, run locally** (`scripts/bot-ci-local.sh`, patches 1–4, the RFC left out;
`tmp/bot-ci-local/co43-20261113/`):
- every build and static check passes: BuildKernel, BuildKernel32, CheckAllWarning,
  CheckSparse, CheckKernelLLVM, IncrementalBuild, SubjectPrefix, VerifyFixes, TestRunnerSetup;
- CheckPatch, VerifySignedoff and GitLint fail only for the missing Signed-off-by;
- the base side (`da3cc0258`) passes its six tree checks too;
- the bot's file mapping selects no tester for a btusb-only change. The emulation above is
  what exercises the code.

**Open before any send:**
1. **D changes the system-resume path** of every btusb device that is reset-resumed at a
   system resume. That is one USB reset more, before a rebinding they already got.
   - **Affected:** the devices of `btusb_needs_reset_resume_table`, and **all Realtek
     devices** with wakeup disabled (`btusb_suspend()` sets `reset_resume` for them,
     `BTUSB_WAKEUP_AUTOSUSPEND`). The second group is the wider one.
   - **Narrower variant to weigh:** queue the reset only for a runtime resume. This harness cannot test it: `vhci_hcd`
   refuses system suspend while a device is attached (`platform_pm_suspend returns -16`,
   `results/bt17-emulation-2026-11-13/logs/runs/*-pm-sysfreeze-*`). A second emulator on
   Raw Gadget and `dummy_hcd` (`harness/rg-emu.py`) brings btusb up and works before the
   sleep, but it cannot take part in a system resume: the freezer stops the user-space
   gadget until the devices have resumed. raw-gadget then leaves its running state
   ("device is not running"), and the re-enumeration fails (`logs/runs/base-pm-rg-plain-2.log`).
   Next: an in-kernel gadget function for this device, or a real QCA ROME on a spare machine
   with a DMI-table quirk set through `usbcore.quirks=13d3:3503:b`.
2. B makes each queued command time out on its own while the device resumes (three `tx
   timeout` lines in emulation instead of one blocked one). Acceptable, but the maintainers may
   prefer the core not to restore credit then.
3. The bot's CI on base and base + series (`scripts/bot-ci-local.sh`); an outside review.
4. C waits for evidence (a recurrence with USB core debug, an A/B with `power/control=on`).
5. **Four outside reviews of the intermediate document**
   (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`, each finding checked).
   They supersede the plan in item 6.
   - **B:** a blocker. It can skip the reset of an awake controller that swallowed a command:
     the autosuspend and the command timeout are both 2 s (not yet tested). Its exception
     never fires, as our own `ab-recover-1.log` shows. And its message is wrong about where the
     rebinding comes from: from btusb's reset, not from the core.
   - **D:** not as a fix.
     - It opens `autosuspend_check()`'s gate for reset-resume-quirk devices.
     - It replays traffic before the rebinding.
     - It still costs two resets, as unpatched.
     - So BT-18 goes to linux-usb as a USB core question first, with D as the btusb fallback.
   - **CO-44:** add the missing `-EACCES → MGMT_STATUS_AUTH_FAILED` case, once its reach is
     traced.
   - **E and A:** to send alone.
   - **C:** stays local.
   - **A fifth review (reviewer 7, `reviews/2026-11-13T1700Z-…-reviewer-7-verbatim.md`;
     checks 12–21 in the same file).** It reaches the same verdicts, and every source claim
     in it holds. New:
     - **B:** the exact counterexample. `tx_in_flight` drops at USB completion, so a command
       sent but never answered lets the device autosuspend before the timeout. Our
       `--hold-hci` cannot show it; the test needs a dropped HCI event and an autosuspend
       delay under 2 s.
     - **D:** its queued reset can be lost. `usb_lock_device_for_reset()` refuses a suspended
       device and gives up after 1 s, the work drops the request silently, and D holds no PM
       reference. And with `reset_resume` present, the core no longer sets `needs_binding`.
     - **D:** returning on a failed `btusb_resume()` would not help: `usb_resume_both()`
       ignores the result.
     - **BT-24:** `btusb_resume()`'s failure path scuttles `deferred` outside `txlock`, which
       E does not cover. Registered.
     - **The harness:**
       - `--recover` recovers on unlink, not on reset;
       - `recover` judges only that hci0 reappears;
       - failures do not fail the run.

       To be fixed before any further acceptance run.
     - **C's message:** the GET_STATUS failure is inferred, not logged on the laptop; narrow the
       subject.
   - **B's harm, tested (2026-11-13, `results/bt17-emulation-2026-11-13/`, `dropcmd` and
     `dropcmd-wedge`).** A controller completes a command's transfer, never answers it, and
     the device autosuspends before the timeout:
     - **unpatched:** `btusb_reset()` resets it, 6/6;
     - **with B:** it skips the reset, 12/12;
     - **when the controller needs that reset:** unpatched it recovers, 3/3; with B it stays
       dead, 6/6, and nothing later resets it (no command timer during `HCI_RESET`).
     - **B is not to be sent in this form.**
   - **E's `Fixes: 7bee549e197c`:** verified in full history. That commit added the anchoring
     outside `txlock`, as well as BT-20's silent waker and BT-24's scuttle.
6. **The second outside review of the patches (earlier, on the dossiers)**
   (`reviews/2026-11-13T1530Z-bt17-patches-reviewer-2-verbatim.md`, checked there):
   - **Don't send 1–4 as one series.** A and E go separately; B after another review; D only
     after a narrower design.
   - **D:**
     - queue the reset only after a runtime suspend, recording `PMSG_IS_AUTO()` in
       `btusb_suspend()`, so the system-resume path stays as it is;
     - say why the reset is queued even when `btusb_resume()` fails;
     - check the order of the two interfaces' callbacks against `suspend_count`.
     - Prototype and test that variant in the emulator. The runtime path is testable here; the
       system path still is not.
   - **B:** a focused reading of `hci_cmd_timeout()` and `hci_cmd_work()` when B returns early,
     above all when the device is about to be unregistered. Also correct the message's last
     line.
   - **E:** a final review of the lock order and the teardown cases.
   - **Order of sending, by the review's priority:** CO-44, then E, then A, then B, then D;
     C as an RFC only.
   - **`scripts/bt17-arm-usb-debug.sh`:** make the usbmon capture rotate instead of stopping
     at 500 MB, and have `--off` restore the saved state.

**Decides:** the operator, for any send.
*(verbatim: `contributions/CO-44-mgmt-timeout-reported-as-auth-failed/README.md`)*
### CO-44 — MGMT: a command timeout is reported as "Authentication Failed" (BT-21)

**What:** `mgmt_errno_status()` (`net/bluetooth/mgmt.c`) maps `-ETIMEDOUT` to
`MGMT_STATUS_AUTH_FAILED` (0x05). At the laptop's BT-17 incident (2026-11-12 18:03), the
controller did not answer the kernel's Write Class of Device, and bluetoothd logged "Failed to
remove UUID: Authentication Failed (0x05)" three times, although no authentication took
place (`results/incident-2026-11-12-1803/`). `MGMT_STATUS_TIMEOUT` (0x08) exists, and the
HCI-status table in the same file already uses it for Connection Timeout, Host Timeout and
Directed Advertising Timeout.

- **Origin:** `161510ccf91c` ("Bluetooth: hci_sync: Make use of hci_cmd_sync_queue set 1",
  Luiz Augusto von Dentz, 2021-10-27, v5.17-rc1) added the errno table with this entry and
  gives no reason for it (third outside review of BT-17, checked with `git show`).
- **Present in:** bluetooth-next `da3cc0258` (2026-11-12) and Ubuntu's `7.0.0-42`/`-43`.

**State (2026-11-13): patch written and tested in QEMU; nothing sent.**

- **The patch:** `patch/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch`,
  one line, `Fixes: 161510ccf91c`. No Signed-off-by: the operator adds his own.
  checkpatch `--strict --no-tree`: only the missing Signed-off-by, and "Unknown commit id"
  because it ran without a tree.
- **The test:** `patch/0001-mgmt-tester-Add-Set-Device-Class-timeout-test.patch` (`[PATCH BlueZ]`
  on master `20ffd285b`; the same change as `patch/bluez-mgmt-tester-set-dev-class-timeout.diff`), a new mgmt-tester case,
  "Set Device Class - Timeout 1". Its emulated controller drops Write Class of Device (a
  `HCIEMU_HOOK_PRE_CMD` hook returning false, `emulator/btdev.c:8742-8744`). It expects
  `MGMT_STATUS_TIMEOUT`.
- **Measured** (BlueZ `doc/tester.config` kernels, base `da3cc0258` and patched):

  | tester | base | patched |
  |---|---|---|
  | new case | fails: "Unexpected status got Authentication Failed (0x05) expected Timeout (0x08)" | passes (2.050 s) |
  | mgmt-tester, all 527 | 526 passed, 1 failed (the new case) | 527 passed |
  | l2cap-tester | 144 passed | 144 passed |
  | smp-tester | 8 passed | 8 passed |

- **Reach of the change** (an audit of every path into `mgmt_errno_status()`):
  - The sync-queued MGMT commands (Set Powered, Set Device Class, Add/Remove UUID,
    Discovery, Advertising, …) get 0x08 instead of 0x05 when the controller does not answer.
    bluetoothd only logs the text for them (`mgmt_errstr()`).
  - Pairing paths take positive HCI statuses through the HCI table, not this function, so
    they are unchanged; the seven `AUTH_FAILED` expectations in mgmt-tester (pairing
    rejects) still pass.
  - BlueZ already treats 0x08 as a timeout (`src/device.c:3493` maps it to
    "AuthenticationTimeout").
  - A grep of BlueZ's `src`, `profiles`, `plugins` and `tools/btmgmt.c` found nothing that
    depends on 0x05 for a timeout.
- **One other case changes status, with the same verdict:** mgmt-tester "Get Conn Info -
  Power off".
  - The kernel's Read RSSI (`0x1405`) times out during the power-off, and Get Connection
    Information is answered `0x05` on base, `0x08` patched.
  - The test expects `0x0f` Not Powered, logs "Unexpected status got 5 expected 15" (base) or
    "got 8 expected 15" (patched), and **passes anyway**: this test only logs a wrong status.
  - So the patch changes this case too, and the test cannot tell. That is by design: the case
    is declared `fail_tolerant = true` (`tools/mgmt-tester.c`, `get_conn_info_power_off_test`),
    since the emulated controller is powered off under the pending Read RSSI. Not a defect
    signal.
  - With the patch, the reply there reads "Timeout" instead of "Authentication Failed",
    which is the more accurate of the two.
- **Logs:** `logs/excerpt.txt` (the new case's lines and every tester's totals, with each full
  log's SHA-256). The full logs stay local in `agent-work/bt17-mgmt-timeout/logs/` with
  `SHA256SUMS`: they carry the emulated controllers' addresses, which the publishing scan
  cannot tell from real ones.
- **Seen on the way, not fixed:** `unpair_device_complete()` (`mgmt.c:3134`) passes the
  raw negative `err` to `cmd_complete` instead of `mgmt_status(err)`; not traced.

**The list's CI bot, run locally on the kernel patch** (`tmp/bot-ci-local/co44-20261113/`):
- **Passes:** BuildKernel, BuildKernel32, CheckAllWarning, CheckSparse, CheckKernelLLVM,
  IncrementalBuild, SubjectPrefix, TestRunnerSetup.
- **Testers:** `TestRunner_mgmt-tester` passes on both sides, with identical not-passed
  sets (the bot's BlueZ master, without our new case). The kernel-report scan is clean.
- **CheckPatch, VerifySignedoff, GitLint:** fail only for the missing Signed-off-by.
- **VerifyFixes:**
  - first "Target SHA1 does not exist": an artifact of the runner's history limit (2023);
  - rerun with history from 2021-06 (`co44-verifyfixes-20261113/`): only "empty lines
    surround the Fixes tag", because `Fixes:` is the message's last line. The operator's
    Signed-off-by goes directly under it.
- **The base side's one non-pass,** `Mesh - Send cancel - 1`, failed once on the unpatched
  base and passed patched: unrelated to this change (mesh, M-1).

**The list's CI bot, run locally on the BlueZ test** (`--space user`, master `20ffd285b`, the
patched kernel image; `tmp/bot-ci-local/co44-bluez-20261113/`): every check passes on both
sides, 0 not PASS. Patched: CheckPatch, GitLint, BuildEll, BluezMake, CheckSmatch,
bluezmakeextell, TestFunctional, IncrementalBuild, ScanBuild. Base: the same six tree checks.
The bot's user-space checks do not run mgmt-tester; the new case's runs are the table above.

**Four outside reviews** (`reviews/2026-11-13T1600Z-bt17-patches-reviews-checks-and-plan.md`):
- **All four agree on the fix and on `Fixes: 161510ccf91c`.**
- **The missing half, confirmed:** `mgmt_errno_status()` has no `-EACCES` case. So a sync
  command that the controller answers with HCI Authentication Failure (`-bt_to_errno(0x05)` =
  `-EACCES`, `hci_sync.c:189`) is reported as `MGMT_STATUS_FAILED`.
  - **To decide:** add `-EACCES → MGMT_STATUS_AUTH_FAILED`, with a second test, once it is
    traced which commands can receive `0x05` that way.
  - **Traced (2026-11-13, the checks file, finding 9):** `bt_to_errno()` maps both
    Authentication Failure (`0x05`) and Pairing Not Allowed (`0x18`) to `EACCES`. The
    HCI-status table maps them to `AUTH_FAILED` and `REJECTED`, so no single `-EACCES` case
    is right. `ETIMEDOUT`, by contrast, comes only from Connection Timeout (`0x08`),
    Connection Accept Timeout (`0x10`) or no answer, and the table says `TIMEOUT` for all
    three.
    - **Recommendation:** CO-44 stays one line, without the `-EACCES` case.
    - **Below the `---`:** the patch makes the errno path agree with the table.
- **Stable:** split. Two reviewers say yes; one leaves it to the maintainers; one says skip
  `Cc: stable` and state below the `---` that a user-visible status changes.
- **The BlueZ test:**
  - check that the hook actually saw Write Class of Device;
  - send it only after the kernel patch has landed, or the list's CI fails it.
- **A fifth review (reviewer 7)** found no blocker in either patch. It verified
  `161510ccf91c` itself and calls the fix a reasonable stable candidate after normal review.
  - **It lists BlueZ code that treats `AUTH_FAILED` specially:**
    - `bonding_attempt_complete()`'s PIN retry, `src/adapter.c:8933`;
    - `device_bonding_complete()`, `src/device.c:7552`.

    Pairing results reach those through the HCI-status table or explicit mappings
    (`pair_device()`, `mgmt.c:3772-3779`), so the patch leaves them as they are. Our audit
    stands. But the two statuses are not interchangeable to user space in general, and the
    mail must not say so.

**Next:**
- the kernel patch and the BlueZ test as two sends, the test noting that it needs the kernel fix;
- the operator's word for both.

**Decides:** the operator, for the send.
