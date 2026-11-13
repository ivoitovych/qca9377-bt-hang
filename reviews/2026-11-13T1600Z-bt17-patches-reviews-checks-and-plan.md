# BT-17 patches — outside reviews of the intermediate document (four, then a fifth): our checks, and the plan

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

## Where the four agree

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

## The new findings, checked

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

## Reviewer 7, checked

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

## The plan this gives (nothing sent; each send is the operator's)

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
