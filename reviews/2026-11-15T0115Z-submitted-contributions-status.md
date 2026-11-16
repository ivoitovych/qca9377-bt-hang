# Submitted, not yet accepted: live status and options (2026-11-15)

**Revised 2026-11-15 ~02:45 UTC after five outside reviews.** The first version is `48c147a`.
The reviews are stored verbatim (`2026-11-15T0115Z-submitted-status-review-reviewer-*-verbatim.md`)
and checked point by point in `2026-11-15T0300Z-submitted-status-review-checks.md`. Corrected:
- patch 1's hardware test, which the first version denied;
- the CO-02 diagnosis;
- the lock question, which the first version did not raise;
- the date of the maintainer's Sashiko practice;
- several statements that turned observations into causes;
- the grouping of the table.

Read live 2026-11-15 00:40–01:15 UTC, rechecked 01:45–02:45 UTC. Sources:
- patchwork, by `scripts/patchwork-state.py` and `scripts/patchwork-recent.py`, raw JSON in
  `tmp/patchwork/`;
- the linux-bluetooth lore archive over git (a shallow clone: its history has gaps, so "not
  found in it" is not "absent"), and `scripts/lore-git-message.sh` by Message-ID;
- GNOME GitLab, by `scripts/cd-trace/x1-check-submission.py`;
- GitHub, by `gh api`;
- the Sashiko API and the syzbot page.

Textual conflicts were tested with `tmp/upstream-status-20261115/apply-file.sh` and
`apply-alone.sh`.
- **Method:** each copies the file at bluetooth-next `da3cc02587c6` into a scratch repository of
  its own and applies the patches in order. A result counts only if the file changed.
- **A discarded first version:** it applied from inside the project checkout, silently skipped the
  file, and reported every patch as applying. Its results were discarded; the script was new on
  11-15, so no earlier result came from it.
- **Controls:** each verdict below has a positive control. The negative control is v2 2/2 on the
  bare base: it FAILS there, by construction, since its context contains 1/2's lines.

## The table

### Waiting for our action

| Contribution | Sent | State today | What it waits for | Next step |
|---|---|---|---|---|
| CO-02 kernel `[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse` (patchwork 14919266–14919268) | 2026-10-27 | `new`, 19 days, no human reply | Our v2. `sashiko-nipa` (10-29) rated patch 2 `fail`, high: alone it leaves the race patch 3 closes, so fold 3 into 2 or make sure both go to stable together. It was never answered. The mirror PR closed on 11-11, but v2 is needed for its content anyway. | v2 as layout (a), after the lock question below |
| CO-02 BlueZ `tools/sco-tester: Add SCO reconnect tests` (14919269) | 2026-10-27 | `new` | Its old form targets the tester API that changed on 10-29 (`e37f17751`), as its notes foresaw. The v2 tests apply to master `20ffd285b` (checked today). | After the kernel v2, linking it |
| CO-25 `[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware: HCI hang during mSBC SCO` | 2026-10-29 | answered 10-29 by Zijun Hu (Qualcomm engineer): QCA9377 is not ROME, btusb does not support it | Our reply v4, ready since 11-02 (`contributions/CO-25-…/drafts/reply-1-zijun-hu-v4.eml`) | The operator's decision; recommended: send v4 after reading it |

### Waiting for upstream

| Contribution | Sent | State today | Notes |
|---|---|---|---|
| Tested-by on Hui Peng's "Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure" (14831271) | our Tested-by 2026-10-06 (the patch is from 09-19) | patch `new`, 57 days | The identical change was posted again 11-04 by Wentao Liang (14942650). Nothing required; optionally one line naming the duplicate (operator). |
| gvfs MRs !368 "cdda: Limit paranoia read-ahead to avoid playback stalls" and !369 "cdda: Refuse to open invalid and non-audio tracks" (X1) | 2026-11-07 | open, mergeable, pipelines passed | No reviewer, label or comment; no visible technical blocker. A polite ping after about four weeks (operator). |

### Watching

| Contribution | State | Notes |
|---|---|---|
| Reply on BlueZ issue #1554 (2026-10-09) | issue open | The reporter, 10-14: updated to 6.18.50, cannot trigger it on demand. Nothing to do. |

### Done

| Contribution | State |
|---|---|
| Tested-by on 6.6.160-rc2 (CO-10, 2026-10-21) | 6.6.160 released |

The mesh v3 series was never sent; its split is described under "Mesh".

## CO-02: what was wrong with v1 — packaging and dependency boundaries

The evidence was not the weak part:

| v1 part | what it fixes | evidence |
|---|---|---|
| 1/3 hold a reused SCO connection | a second socket's `EBUSY` also drops the first socket's link | The failure: sco-tester "Connect Twice" fails on every unpatched kernel (emulator). The fix: on the laptop, 2026-10-26, 3 of 3 second connects refused while the Shure call's link stayed up with no gap in its voice data (`experiments/results-2026-10-26-hw-connect-twice.md`, `EX-075`–`EX-077`). There was no unpatched hardware control. |
| 2/3 don't reuse an aborting connection | U7: after a headset profile switch no link follows | On the laptop: the earbuds' 3 switches refused, then a new link; MOMENTUM 4 2/2 and Shure 6/6 a new link (`EX-067`–`EX-074`). Also sco-tester. |
| 3/3 wait for running disconnect work | the interleaving 2/3 leaves open | QEMU, with a debug-only delay that widens a real window |
| BlueZ sco-tester test | regression tests for 1–3 | The bot passed it. A test that fails before its kernel fix is expected. |

What was wrong was the cut:
- 2/3 and 3/3 are one concurrency fix, posted as two patches.
- Both were tagged for stable, so 2/3 could be taken without the part that completes it.

Testing in an emulator and posting a kernel-dependent test beside the kernel work are not mistakes
in themselves. The stable rules ask for a real, tested fix, not a hardware reproduction.

How the pieces depend on each other, checked today on bluetooth-next `da3cc02587c6`:
- The folded fix (v2 2/2) does not apply without v2 1/2.
- That dependency is also semantic. 2/2's new error path drops a hold on the reused connection,
  and only 1/2 makes that hold exist: on the base, `hci_conn_link()` returns an existing link
  without taking a hold (`hci_conn.c` l. 1870–1882).
- So 1/2 and 2/2 are a genuine two-patch series, and 2/2 must not be backported alone. The cover
  and 2/2 should say so.
- The air-mode mismatch patch ("don't change the parameters of a SCO link in use") comes from the
  11-02 round (decision D2). It was tested in QEMU on 11-02 (315 runs), and incoming-link cases
  were added on 11-14.
  - It is a separate defect, older than the series.
  - Its current file applies only on top of 1/2 + 2/2; a version against the bare base is being
    made.

The v2 package (`contributions/CO-02-…/send-v2-review-fixes-20261114/`) has two layouts:
- **(b)**, three kernel patches: hold, the folded fix, mismatch. It fixes v1's cut, but it adds a
  second defect to the series.
- **(a)**, `[PATCH v2 0/2]` (hold + folded fix), with the mismatch patch as its own submission.

> **Note of 2026-11-16 (this page is a record of 2026-11-15 and is not rewritten):** the v2
> package named above, `send-v2-review-fixes-20261114/`, is superseded: its 2/2 waits under
> `hdev->lock` and hangs 3 of 3 against controller unregister with delays (2026-11-15), so it is
> not to be sent. The candidate is 1/2 plus the non-sleeping 2/2 in
> `contributions/CO-02-sco-connect-reuses-closing-link/review-fixes-20261115/patches/alt-2of2/`,
> with its cover rewritten on 2026-11-16 in `.../msg/cover-alt.txt`. The lock question this page
> calls open is answered there (`.../review-fixes-20261115/README.md`, section 1).

(a) matches the dependencies. Answering Sashiko needs more than "folded": the cover must say why
the synchronization is correct. That brings up the open question below.

### Open before any resend: a possible lock cycle (reviewers 2 and 7)

2/2 waits in `cancel_delayed_work_sync(&sco->disc_work)` with `hdev->lock` held. The 11-14
analysis (`cancel-sync-analysis.txt`) describes a possible three-way cycle:
- connect holds `hdev->lock` and waits for the disconnect worker;
- the worker waits for `cmd_sync_work_lock`;
- `hci_cmd_sync_clear()` holds `cmd_sync_work_lock` and runs destroy callbacks that take
  `hdev->lock`.

Its claim about the callbacks is half wrong:
- `add_device_complete()` takes the lock only when `!err` (`mgmt.c:7856`), so it adds no edge
  on `-ECANCELED`;
- `add_ext_adv_params_complete()` does take it unconditionally (`mgmt.c:9259`), so the edge still
  exists.

That the same order already exists in `hci_conn_del()` does not show that a second wait, at
another point of the lifecycle, is safe. Reachability is not settled. The SCO lane is working on:
1. a corrected analysis;
2. a lockdep-targeted QEMU test on base and v2;
3. a non-sleeping alternative for 2/2 if the cycle is reachable;
4. a variant rebased on Wentao Liang's patch;
5. the `READ_ONCE()` at `hci_abort_conn()`'s top check;
6. the standalone mismatch patch;
7. the stable note.

Until then 2/2's message must not say the wait is safe. The 3-of-33 hangs on one debug-only
kernel (11-14) stay open, not attributed.

## Work in flight next to ours (all `new` unless stated)

| their patch | area | relation to ours | verified |
|---|---|---|---|
| Wentao Liang 14942649 "delete the new SCO link if linking it fails" (11-04, `Cc: stable`) | `hci_connect_sco()` | Same failure branch as v2 1/2 and 2/2. His bug is real by the source. v2 1/2 keeps it (its `else` still drops an unheld new connection): it neither fixes nor worsens it, and 2/2 adds nothing on that branch. A rebased variant is being made; a neutral sentence in the v2 notes should name his patch. | textual conflict both ways, tested |
| Hitalo Souza v3 14875449–54 (10-08), SCO abort handling: "Disconnect links that complete while being aborted", "Don't set up a SCO link that is already up" | `hci_event.c`, `hci_conn.c` (`hci_enhanced_setup_sync()`, `hci_sco_setup()`) | Same subject as CO-02 2/2, different functions. v2 1/2 + 2/2 apply on top of 2/6. The maintainer engaged on 10-07/08 (Sashiko findings, a request for tests), and the series has been `new` since. | tested |
| Wentao Liang 14942650 "free the mesh tx if queueing the send fails" (11-04) | `mesh_send()` | identical change to Hui Peng's 14831271 | diffs compared |
| Jens Willmer 14973994 "btusb: Wait for setup to finish before system sleep" (11-11; the maintainer forwarded Sashiko's findings 11-12, the author answered) | `btusb_main.c`: `struct btusb_data`, a PM notifier | CO-43 E, A and BT-24/25 apply on top of it. The series' patch 2 (B2) does not. D v2 applies, and sits in the same reset-resume / system-sleep path. | tested, with positive controls |
| Daan Bouwman 14976888 "Add QCA Rome support for Surface Laptop 3 AMD (0cf3:e303)" (11-12) | btusb quirks table | same table and failure class as CO-22's ID request; `0cf3:e303` is not in CO-22's list | `git grep` |
| Zijun Hu 14938724 "Fix SCO/eSCO Transport_Unit_Size for HCI data path" (11-03) | `hci_enhanced_setup_sync()` | no overlap with CO-02 or CO-21 | hunk headers |
| Weihong Guan, advertising set by handle (accepted, in the tip); Piyus Kedia 14969999; Cen Zhang 14927631 | `hci_sync.c` advertising | CO-38 and CO-12 territory; CO-38 was refreshed on the tip that holds Weihong Guan's; 14927631 is the one D5 waits on | patchwork |
| bluetooth-next split `btusb.c` into `btusb_main.c` and others | btusb | every package already targets `btusb_main.c` | `git grep` |

## Mesh

Since 2026-09-01, 14 mesh-titled patches were posted. Two kernel mesh fixes were accepted:
- Lee Jones's, after three versions;
- one by Pauli Virtanen.

Six other fixes by five authors are pending: Hui Peng ×2, Jiale Yao, Cen Zhang, Igor Putko and
Wentao Liang. syzbot's "slab-use-after-free Read in mesh_send_sync" is still open (first crash
42 days ago, last 28, two patch-testing requests).

CO-04 is our own standalone fix for that bug: the route decided on 10-28. It can go out in the
paced order below. CO-05 + CO-26 and CO-14 stay held. CO-06's single overview message on the mesh
transmit path remains an option.

## The list as a whole (patchwork, posted 2026-10-27 to 11-14, states as of 11-15)

Observations, not causes.
- **Volume and states:** 383 kernel patches (66 accepted, 165 superseded, 152 `new`); 356 BlueZ
  patches (79 accepted). Silence is the common state: 152 kernel patches have no decision. A
  series the maintainer engaged with (Hitalo Souza's) has been `new` for 38 days.
- **Singles vs series:** in this snapshot, 22 % of single kernel patches are accepted against 15 %
  of patches in series. The figure mixes revisions and submission ages, and it does not estimate
  the chance of eventual acceptance.
- **Automated reviews:** the maintainer points authors to Sashiko's findings, or to the mirror's
  Copilot review, before going further.
  - At least since 2026-10-07: Hitalo Souza's SCO abort series.
  - Regularly in November: six mails since 11-11 in the local clone.
  - An unanswered high finding is therefore a probable obstacle to review. That it is the reason
    CO-02 has no human reply is not established.
- **The 11-04 episode:** a prominent kernel maintainer objected publicly to a batch of untested
  patches, spread over subsystems and ungrouped. The lesson: a large batch creates review load.
  It does not follow that ours would be judged the same.

## Options

1. **CO-02:** v2 in layout (a), after the lock question is settled.
   - Before the send day:
     - the operator's D1/D2, restated with a recommendation in the checks file;
     - the 11-14 checks;
     - a fresh `format-patch --base`;
     - the bot's CI on base and base + ours.
   - The mismatch patch goes later, on its own, against the base.
   - The BlueZ tests follow their kernel changes.
2. **CO-25:** send reply v4 after the operator reads it (recommended). This is independent of
   everything else.
3. **Pacing:** one complex series under revision at a time (CO-02), plus small independent tested
   patches at a steady pace, without waiting for a human reply to each.
   - Proposed order: CO-44 first, CO-38 about a week later, then CO-04.
   - Answer any automated finding within days, without taking it as automatically right.
4. **CO-43 series:** rebase B2 if Jens Willmer's notifier lands. D v2 stays held.
5. **Hui Peng's thread, gvfs:** nothing now (optional pings as in the table).

Nothing was sent or posted.
