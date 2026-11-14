# Kernel patches ready to send — five outside answers, and our checks (2026-11-14)

Answers to `2026-11-14T0300Z-kernel-patches-ready-to-send-for-outside-review.md`. They come from
reviewers 1, 2, 3, 6 and 7 and are stored verbatim as
`2026-11-14T0300Z-kernel-patches-review-reviewer-<n>-verbatim.md`. They are opinions to weigh, not
verdicts.
- Reviewers 6 and 7 verified the 51 embedded hashes and applied every patch to the pinned bases.
- Reviewer 2 read the source at the base.
- Reviewer 3 read the patch files and the source.
- Reviewer 1 assessed from the descriptions, and says so for item 10.
- None of them ran a build or a test.

Marks used below: **[verified]** means checked here today against our files or `cache/`;
**[wrong]** means checked and found incorrect; **[open]** means not yet checked.

## The answers in one table

| # | item | R1 | R2 | R3 | R6 | R7 | where they agree |
|---|---|---|---|---|---|---|---|
| 1 | CO-44 | send | send, fix the brief | send, + stable | send, drop `Link:` | send, fix the brief | send; fix the brief's sentence and the BlueZ placeholder |
| 2 | E | send | send | send | send | send | send |
| 3 | A | send | send, soften | send | send, rate-limit | send, fix the order of events | send after the message fix |
| 4 | CO-38 | send | kernel; split BlueZ | kernel; split BlueZ | kernel; split BlueZ | kernel; split BlueZ | kernel now; split the BlueZ tests |
| 5 | CO-04 | send | another locking review | send; syzbot test; stable size | send after 2 wording fixes | send; narrow the scope | send after the wording fixes; a syzbot test is wanted |
| 6 | CO-05+26 | send | narrow the wording | send after CO-04 | one series with 5 | two patches; exact wording | narrow the wording; after or with CO-04 |
| 7 | CO-35 | send | send; deviation table | repackage (100-line rule) | send | send after wording and queue checks | refresh the queues; the prerequisite's size is disputed |
| 8 | CO-22 | send | send; recheck queue | send | send | send; date claim overstated | send after a queue refresh |
| 9 | CO-21 | send | revise (snapshot, mixed mode) | ready; locking a question | send, `air_mode` first | revise (snapshot) | revise the snapshot before sending |
| 10 | CO-20 | send | 1 yes, 2 revise | 1 yes, 2 RFC | 1 yes, 2 optional | 1 yes, 2 defer | patch 1 alone; patch 2 held |
| 11 | CO-43 rest | hold | hold | hold; D v2 blocker | hold 2 and 3 | hold; D v2 blocker | hold B2 and D; send BT-24/25 alone |
| 12 | CO-02 v2 | send | 1–2, 3 apart | 1–2, 3 apart | send three | send three | send; whether to split patch 3 is disputed |

Reviewer 6 also advises against volume: about twenty patches in a day, with CO-02 v1 unanswered
since 10-27, invites triage by volume. Lead with items 1 and 4.

## Per item: checks and what follows

### 1. CO-44
- **[verified] The brief is wrong.** "`mgmt_errno_status()` has no case for it": the function has
  `case -ETIMEDOUT`, which returns the wrong status. The sentence comes from
  `scripts/kernel-review-pack/build.py:37`; the commit message is right. Fix: build.py.
- **[verified] The BlueZ mail carries the literal `@KERNEL_PATCH_LINK@`**, as do
  `send-commands.txt` and `NOTES-FOR-OPERATOR.md`. It is a deliberate placeholder for the kernel
  mail's lore link, which exists only once that mail is posted. The send steps must fill it.
  Keep it, and make the step explicit in `send-commands.txt`.
- **`Cc: stable`:** R1, R3 and R7 are for it; R2 says it is not needed. It is the operator's call;
  `cc-stable-variant.txt` is ready.
- **`Link:`:** R6 says drop it, R2 and R7 call it optional, R1 calls it useful. Operator.
- **Subject:** R7 offers "Bluetooth: MGMT: Report command timeouts correctly". Operator.

### 2. E
- All five say send. On the stable Cc, R1 and R7 are for it, R2 and R3 against: the race was not
  seen naturally, and the stable rules discourage theoretical races. Operator.
- R6 notes that the `failed:` path still scuttles outside `txlock`, and only BT-24's fix closes
  that. It agrees that E's message is scoped accurately.

### 3. A
- **[verified] The order of events in the message is wrong.** A's own `CHECKS.md` table shows Set
  Device Class at 9.378, `tx timeout` at 11.412, and the new failed-resume line at 16.533. The
  timeout comes first, about 5 s before the failed resume is logged. R7's replacement text is
  accurate.
- **Rate-limit the line** with `bt_dev_err_ratelimited()`: R6 is for it, R7 calls it a defensible
  refinement.
- Send A on its own or as 1/5, not both (R6).
- No `Fixes:` (R1, R2, R3, R7). R3 of 11-13 had suggested `7bee549e197c`; outvoted.

### 4. CO-38
- Kernel: all five say send. R3 and R7 favour `Cc: stable` (a deterministic two-line fix). Operator.
- **BlueZ: split. Four of five agree.**
  - Patch 1/3 brings in duration cases that fail until CO-12, which is not posted.
  - The instance-2 test needs helpers from patch 1.
  - Send the helpers and the instance-2 case now; hold the eight duration cases with CO-12.

### 5. CO-04
- **[verified] "only completes the request, as before"** (message line 45): before the patch that
  path also cleared `HCI_MESH_SENDING`; now the flag stays set. Reword (R6).
- **The patch comment "is handed over by mesh_send_done_sync()"** (patch line 250): R6 and R7
  independently say that after an on-air cancel, the list head is the next, unsent request. It
  then gets its completion without being sent. Both say the behaviour is pre-existing.
  - **[open]** Fix or reword.
  - R7's test: A running, B queued, cancel A; B must start and get its own completion.
- **R2's point:** the `-ECANCELED` completion from `hci_cmd_sync_clear()` removes and frees a list
  entry without `hdev->lock`, and `mesh_send_done_sync()` reads `adv_instances` before the lock.
  - Both are pre-existing.
  - **[open]** An audit on the unregister path, the same ground as CO-14 (M-4) and M-5.
- **A syzbot `#syz test`** is wanted by R2, R3, R6 and R7. That is a mail to an outside service,
  so it is the operator's decision.
- **[verified] Stable size:** the patch has 156 changed or context lines against stable's limit of
  100 (R3). R3 suggests no Cc now and a smaller backport after the merge; R1 and R7 keep stable.
  Operator.
- **R6 suggests Cc'ing the authors of the competing patches.** The project's standing rule for
  patch 14888791's author is no direct cooperation. The operator decides; nothing changes by
  default.

### 6. CO-05 + CO-26
- **[wrong] R7's "adds and removes"** is about the cover's description of a *test*: "a test that
  adds and removes an advertising instance on one socket". It is not about `mesh_send_sync()`. No
  change.
- **Narrow the wording** (R2, R7): it fixes the mesh insertion and capacity-check race, not the
  lifetime of every advertising instance. The cover already names `hci_schedule_adv_instance_sync()`.
- **[verified] CO-26 says it is "a cleanup of the error path"** and carries `Fixes:`, which
  invites an automatic stable backport (R6). Either drop `Fixes:` or reword. Operator.
- **Order:** R3 says after CO-04 is merged; R6 says one series with CO-04; R7 says separate with a
  cross-reference, or a series with CO-04 first. Operator; the default is to send after CO-04.

### 7. CO-35
- **The prerequisite's size.** `608e0b7a675b` is 149 lines against stable's 100.
  - R3: backport only the two helpers `32d86e048d8e` needs, as a reduced prerequisite, on 7.3 too.
  - R7: asking for an exception, as the cover does, is fine and is the maintainers' call.
  - **[open]** R3's variant needs building and testing. The choice between the two is the
    operator's.
- **The sanitizer wording.** The covers say "No lockdep or KASAN report".
  - R7 quotes a record saying the tester config had hung-task detection only. That line is ours:
    `send-20261102/results.md:157`.
  - **[verified]** BlueZ's `doc/tester.config`, which `build.sh` copies first, sets
    `CONFIG_PROVE_LOCKING=y`, `CONFIG_LOCKDEP=y` and `CONFIG_KASAN=y`.
  - **[open]** Whether they survived into the built `.config`: the build trees are gone.
  - Either confirm and correct the 11-02 line, or reword the covers to what is confirmed.
- **A deviation table per backport** (R2). The data is in the covers.
- Keep the SCI request (`5874f8d03268`) separate (R2, R7). Refresh the queues before sending (R2, R7).

### 8. CO-22
- **[verified] The request overstates how fresh its check is** (R7). The mail says "checked
  2026-11-14"; the README says 7.3 to 6.1 were checked on 11-14 at 01:05, but 5.15 and 5.10 only
  on 11-02. Refresh all seven before sending, then state the date.
- Do not add `0cf3:e303` (R2, R7; already removed on 11-14).

### 9. CO-21
- **[verified] `conn->air_mode` is set after `conn->state = BT_CONNECTED`**, in
  `hci_sync_conn_complete_evt()` (patch 1). Set it first (R6, R7).
- **One snapshot** (R2, R7; R3 calls it a review question). Take both counts in one helper under
  `hdev->lock`, with `lockdep_assert_held()`, and release it before any USB call.
  - R7's interleaving: the CVSD walk returns 0, a CVSD link comes up, the transparent link goes
    down, the transparent walk returns 0, and alt 0 is chosen with a link up.
  - Add a transition test and KCSAN coverage.
- **Mixed CVSD and transparent links:** R2 and R7 ask whether the transparent setting carries both.
  **[open]** Look in the spec or the source, or make it an emulator case.
- No stable on the first posting (R3, R6). The two patches travel together.

### 10. CO-20
- Patch 1: all five say send it alone.
- **Patch 2: hold.**
  - R7's case: A and B are transparent links, A closes, and B is quiet on the same setting. A's
    handle stays remembered, and a malformed frame matching it is excluded from `err_rx`.
  - Options: track recently closed handles from the core, or call the result a heuristic and leave
    `err_rx` as it is.

### 11. CO-43, the rest
- **The D v2 blocker** was found three times independently: our checks this morning
  (`2026-11-14T1300Z-…-reviewer-3-checks.md` §1), R3 and R6.
  - Registering `reset_resume` removes `needs_binding` on a system reset-resume.
  - The callback also lifts `autosuspend_check()`'s exclusion (R2, R6, R7).
- **More for B2:**
  - **Late submission** (R6, R7): a timed-out deferred command is replayed on a slow successful
    resume, with no reset. R6 suggests discarding the parked URB in the deferred branch.
  - **Not per command** (R2): `BTUSB_CMD_DEFERRED` cannot tell whether *the* timed-out command
    was the deferred one. Either show the serialization invariant or track commands.
  - **R6:** a manual reset through sysfs goes through `hdev->reset` and would be refused.
  - **Order** (R7): patch 2 needs patch 3 but comes before it.
- **D v2's queued reset** can still be dropped if `usb_lock_device_for_reset()` fails. The PM
  reference then stays held (R2).
- **Extract BT-24 and BT-25** (R2, R3, R6, R7): rebase them on E without `BTUSB_CMD_DEFERRED`,
  rerun the focused checks, and send them as their own series.
  - R2: check `btusb_close()`, which drains outside `txlock`.
  - R7 supports the `Fixes:` origins, `7bee549e197c` and `19cfe912c37b`.
- **The linux-usb question first** for BT-18 (R3, R7).

### 12. CO-02 v2
- **Split or not.** R2 and R3: send 1 and 2 as v2, and patch 3 separately. R6 and R7: keep
  three. Operator.
- **[open] The cover's "6.18.y and 7.2.y"** (cover line 66): R6 says 7.2.y is end of life and it
  should read 7.3.y. Check `e6720779ae61` against v7.3.4, then fix.
- **R2's checks:**
  - an incoming-SCO test for patch 3's no-owner case (a remote-established link and a local
    socket attaching);
  - audit every reader of `abort_reason`, since the check at the top of `hci_abort_conn()` is
    still a plain load;
  - validate `cancel_delayed_work_sync()` under `hdev->lock`. R7 gives the source argument that it
    is safe for SCO/eSCO.
- **R3's wording:** "while the connection has a holder", not "a socket holds it".
- **R7's wording:**
  - the codec comparison covers the voice setting, codec id and data path, not `cid`/`vid`;
  - say "no causal evidence found" instead of "cannot be involved" for the l2cap stalls.

## What is done here, what goes to lanes, what is the operator's

- **Done now (text only):** item 1's sentence in build.py, and the review document rebuilt.
- **To lanes (each tested base against patched, at low priority):**
  1. **btusb:**
     - BT-24/25 extracted on E;
     - A's message and the rate limit;
     - CO-21's snapshot, with `air_mode` set first;
     - CO-20 patch 1 alone.
  2. **MGMT:**
     - CO-38's BlueZ split;
     - CO-04's wording and R7's cancel test;
     - the R2 unregister audit;
     - CO-05's wording;
     - CO-44's `send-commands.txt` step.
  3. **SCO:**
     - CO-02 v2 as 2 + 1 and as three;
     - the incoming-SCO test;
     - the `abort_reason` readers;
     - the cover's stable lines.
  4. **stable:**
     - CO-35's sanitizer record;
     - the deviation table;
     - R3's reduced-prerequisite variant, built and tested;
     - queue refresh for CO-35 and CO-22.
- **Operator:** the stable Cc on items 1, 2, 4 and 5; CO-44's `Link:` and subject; the syzbot
  test mail; Cc of other authors; the CO-05 order and CO-26's `Fixes:`; CO-35's exception or the
  reduced prerequisite; the CO-02 split; the send order, for which R6 advises leading with 1 and 4.
