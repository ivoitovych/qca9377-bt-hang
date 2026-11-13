# BT-17 patches — four outside reviews of the intermediate document: our checks, and the plan

*2026-11-13. The four answers to `2026-11-13T1100Z-bt17-patches-intermediate-review.md` are
kept verbatim beside this file:*
- *`2026-11-13T1600Z-bt17-patches-review-reviewer-1-verbatim.md`;*
- *`…-reviewer-2-verbatim.md`;*
- *`…-reviewer-3-verbatim.md`;*
- *`…-reviewer-6-verbatim.md`.*

*Reviewer 2's earlier assessment of the dossiers is
`2026-11-13T1530Z-bt17-patches-reviewer-2-verbatim.md`. Each claim below was checked against
bluetooth-next `da3cc0258` (`git show`/`git grep` in the emulation worktree) or against our own
emulation logs (`results/bt17-emulation-2026-11-13/logs/runs/`).*

## Where the four agree

| item | R1 | R2 | R3 | R6 | consensus |
|---|---|---|---|---|---|
| 1 (A) | nit, ready | nit | nearly ready | nit (wording) | send alone after a wording fix |
| 2 (B) | should-fix | should-fix (B1 untested) | **blocker** | **blocker** | rewrite, after BT-18 is fixed |
| 3 (D) | should-fix | **blocker** | **blocker** | RFC to linux-usb only | not as a fix; take BT-18 to the USB core |
| 4 (E) | ready | strong, one stress test | ready | ready (+ `Fixes:`) | send alone |
| 5 (C) | RFC ok | RFC only | not as a fix | don't post | keep local; an A/B on the laptop at most |
| CO-44 kernel | ready, stable | nit, stable for the maintainers | add `-EACCES` | send, no `Cc: stable` | send, after the `-EACCES` question |
| CO-44 test | — | verify the hook fired | add an auth-failure test | send after the kernel patch lands | refine, send second |

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
10. **Patch E's `Fixes:`** (R6: `7bee549e197c`). **Not checked:** the emulation tree is shallow
    and does not hold that commit. To check in a full-history tree before sending.
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
5. **B afterwards:** rewrite it on top of the BT-18 fix, with no exception. Test it in the
   emulator against a dropped command on an awake controller (finding 1) and against A+B alone
   (finding 2), judged by a command after the recovery.
6. **C:** keep it local.
7. **Doc fixes now:** the emulation README title, and the dossiers' statements on resets
   (finding 4).
