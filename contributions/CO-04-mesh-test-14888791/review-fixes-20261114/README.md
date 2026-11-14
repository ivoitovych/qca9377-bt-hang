# CO-04: the 2026-11-14 outside review answered

`../../../reviews/2026-11-14T1400Z-kernel-patches-review-answers-checks.md` §5 holds the review
points. `patch/` (mail form) and `patch-bare/` replace `../send-20261114/patch/` for the send.
Their code is unchanged: only the message, one comment and the notes below `---` differ.

- **The message:** "only completes the request, as before" now says that the callback no longer
  clears `HCI_MESH_SENDING` on that path, and why that is harmless at unregister:
  - `HCI_UNREGISTER` is already set;
  - `hci_cmd_sync_queue()` returns `-ENODEV`;
  - the flag is read only by `mesh_send()` and `mesh_send_done()`;
  - `mgmt_index_removed()` cancels `mesh_send_done()`.
- **The comment:** "handed over by mesh_send_done_sync()" is replaced by a description of what
  happens. The on-air request has already been completed, and its pending `mesh_send_done()` work
  ends the air time and hands over.
- **Reviewer 7's test** (A on air, B queued, cancel A), 5 boots per kernel, legacy and extended
  advertising:
  - The 20 case runs behave the same on base and on base + CO-04: B never gets a start, and gets
    its completion when A's air time ends, 82 to 102 ms later (`logs/cancel-active-summary.txt`).
  - This is pre-existing, and the patch's notes say "not changed here".
  - A fix would need to track which request is on air and end its air time on cancel. That changes
    the completion timing a client sees, so it is not part of CO-04. It is recorded as a separate
    follow-up.
- **Reviewer 2's audit:**
  - **The `-ECANCELED` free.** It frees the request without `hdev->lock`, and at unregister a race
    window exists in principle: a Mesh Send that already holds a device reference can still add
    under the lock.
  - **KCSAN:** 80 boots (UnregSweep and unregister, 20 each, on the tip and on tip + CO-04) gave no
    report in mesh, advertising or pending-command code.
    - The reports that do appear are in the test machinery, on both sides: `vhci_poll` /
      `skb_queue_tail`, `hvc_write`, `ps2` (`logs/kcsan-report-titles.txt`).
    - The code is the same before CO-04, so this is pre-existing.
  - **The unlocked `list_empty(&hdev->adv_instances)`:** pre-existing, next to CO-05's area. CO-05
    does not cover this site.
  - **M-5:** removed by CO-04.
  - **M-4:** the other half of removal, which CO-14 fixes.
- **checkpatch:** clean apart from the missing Signed-off-by (`checkpatch.log`).

**Checked on copy:**
- the code-line diff against `../send-20261114/patch/`: only the comment differs;
- the 20 cancel-test lines;
- the KCSAN titles of every boot.

**Left in the work area:**
- the raw guest logs, which print emulated addresses;
- one first run that used a wrong test filter. It is not used for any result.
