# Submitted, not yet accepted: live status and options (2026-11-15)

Read live 2026-11-15 00:40–01:15 UTC. Sources:
- patchwork, by `scripts/patchwork-state.py` and `scripts/patchwork-recent.py`, raw JSON in
  `tmp/patchwork/`;
- the linux-bluetooth lore archive over git, fetched today, read by `scripts/lore-git-replies.py`;
- GNOME GitLab, by `scripts/cd-trace/x1-check-submission.py`;
- GitHub, by `gh api`;
- the Sashiko API and the syzbot page.

Textual conflicts were tested with `tmp/upstream-status-20261115/apply-file.sh` and
`apply-alone.sh`. Each copies the file at bluetooth-next `da3cc02587c6` into a scratch repository
of its own and applies the patches in order. A result counts only if the file changed. The first
version of the script applied from inside the project checkout, silently skipped the file, and
reported every patch as applying; those results were discarded. Each verdict below has a positive
control.

## The table

| # | Contribution | Where, sent | State today | Human response | What blocks it | Overlap with work in flight | Next step (whose) |
|---|---|---|---|---|---|---|---|
| 1 | CO-02 kernel `[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse` (patchwork 14919266–14919268), `Cc: stable` on all three | linux-bluetooth, 2026-10-27 | `new`, 19 days | none | Sashiko (10-29) rates patch 2 `fail`, high: alone it leaves the race patch 3 closes, so fold them. It was never answered. The mirror pull request bluetooth-next #1009 was closed 11-11 23:58 UTC; the CI bot's rule is that such a series must be resent. | Wentao Liang 14942649 (11-04) rewrites the same `hci_conn_link()` failure branch of `hci_connect_sco()`. Tested both ways: our v2 1/2 and v2 2/2 do not apply on top of it, and it does not apply on top of them. Zijun Hu 14938724 (11-03) is in the same file but another function: no overlap. | v2 resend (layout (a), below); the operator's D1/D2 and the 11-14 checks first |
| 2 | CO-02 BlueZ `tools/sco-tester: Add SCO reconnect tests` (14919269) | linux-bluetooth, 2026-10-27 | `new` | none (the CI bot asked for a resend, 11-12 00:36 UTC) | The v1 test was written for the old tester API, and the tester rework landed 10-29 as `e37f17751` (authored 10-21). It is meaningful only after the kernel fix. | none | The v2 tests apply to BlueZ master `20ffd285b` (checked today); send after the kernel v2, linking it |
| 3 | CO-25 `[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware: HCI hang during mSBC SCO` | linux-bluetooth + Qualcomm Cc, 2026-10-29 | answered | Zijun Hu (Qualcomm), 10-29: QCA9377 is not ROME, btusb does not support it | Our clarifying reply v4 has been ready since 11-02 (`contributions/CO-25-…/drafts/reply-1-zijun-hu-v4.eml`) and is not sent. No other reply on the thread. | Zijun Hu is active in the same code: 14938724 (SCO transport unit size, `hci_conn.c`) | Send reply v4 or close the thread (operator) |
| 4 | Tested-by on Hui Peng's "Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure" (14831271) | linux-bluetooth, 2026-10-06 | patch `new`, 57 days | none from maintainers | Maintainers have not taken up any of the mesh fixes (below) | Wentao Liang 14942650 (11-04) posts the identical change (same hunk, line for line) as a new patch with `Cc: stable` | Nothing required; optionally one line on Hui Peng's thread naming the duplicate (operator) |
| 5 | gvfs MRs !368 "cdda: Limit paranoia read-ahead to avoid playback stalls" and !369 "cdda: Refuse to open invalid and non-audio tracks" (X1) | GNOME GitLab, 2026-11-07 | open, mergeable, pipelines passed | none: no reviewer, assignee, label or comment | Reviewer time only | none found | Wait; a polite ping on the MRs after about four weeks (operator) |
| 6 | Reply on BlueZ issue #1554 | GitHub, 2026-10-09 | issue open | reporter, 10-14: updated to 6.18.50, cannot trigger it on demand | nothing | – | Nothing; read again if the reporter writes |
| 7 | Tested-by on 6.6.160-rc2 (CO-10) | stable, 2026-10-21 | 6.6.160 released | – | – | – | Done |
| – | Mesh v3 (5 kernel + 4 BlueZ) | not sent as one series | split; steps 1–2 done | – | see "Mesh" below | six other-author mesh fixes pending | Hold |

## Was CO-02 overcomplicated? Yes: cut wrong, mixed evidence, coupled

v1 was one mail thread carrying four claims of different strength. The kernel patches all had
`Cc: stable`; the BlueZ test went in a separate mail that depended on them.

| part | what it fixes | strongest evidence | weakness |
|---|---|---|---|
| 1/3 hold a reused SCO connection | a second socket's `EBUSY` also drops the first socket's link ("Connect Twice") | sco-tester in QEMU | not exercised on the laptop |
| 2/3 don't reuse an aborting connection | U7: after a headset profile switch no link follows | the laptop, 3 of 3 earbud switches refused, then a new link | alone it leaves a race (Sashiko) |
| 3/3 wait for running disconnect work | the race 2/3 leaves | QEMU with a debug-only delay | not separable from 2/3: one fix cut in two |
| BlueZ sco-tester test | regression tests for 1–3 | the bot passed it | needs the kernel fix to pass; its API was reworked two days after |

How the pieces depend on each other, checked today on bluetooth-next `da3cc02587c6`:
- The folded fix (v2 2/2) does not apply without v2 1/2.
- That dependency is also semantic. 2/2's new error path drops a hold on the reused connection,
  and only 1/2 makes that hold exist: on the base, `hci_conn_link()` returns an existing link
  without taking a hold (`hci_conn.c` l. 1870–1882 at `da3cc02587c6`).
- So 1/2 and 2/2 are one honest two-patch series.
- The air-mode mismatch patch ("don't change the parameters of a SCO link in use") applies on top
  of them, but it is a different defect, older than the series, and it was tested only in QEMU.

What this means for maintainers:
- A series is judged as a unit. Sashiko's red mark on 2/3 stood unanswered over the whole series.
- Six of the maintainer's list mails since 10-15 mention Sashiko, all from 11-11 on (lore,
  searched by author and text). In them he sends authors to Sashiko's findings, or to the
  mirror's Copilot review, before going further. So an unanswered automated finding now plausibly stops a series.

The v2 package has two layouts (`contributions/CO-02-…/send-v2-review-fixes-20261114/`):
- **(b)** three kernel patches and two BlueZ tests. This repeats v1's shape.
- **(a)** `[PATCH v2 0/2]` (hold + folded fix), the mismatch patch as its own mail, and each BlueZ
  test paired with its kernel change.

(a) is the one that matches how the code actually depends. The cover should answer Sashiko's
point in one sentence (2 and 3 folded) and keep the change log short.

## Work in flight next to ours (all `new` unless stated)

| their patch | file / area | relation to ours | verified |
|---|---|---|---|
| Wentao Liang 14942649 "delete the new SCO link if linking it fails" (11-04, `Cc: stable`) | `hci_connect_sco()` | Same lines as CO-02 v2 1/2 and 2/2: whichever lands first, the other needs a rebase. Its claim holds by the source (above): a new SCO connection's only hold comes from the link. The same failure branch survives in our 1/2's `else`. | textual conflict both ways, tested |
| Wentao Liang 14942650 "free the mesh tx if queueing the send fails" (11-04) | `mesh_send()` | identical change to Hui Peng's 14831271, on which we gave the Tested-by | diffs compared |
| Jens Willmer 14973994 "btusb: Wait for setup to finish before system sleep" (11-11; the maintainer forwarded Sashiko's findings 11-12, the author answered the same day) | `btusb_main.c`: `struct btusb_data`, a PM notifier | CO-43 E, A and BT-24/25 apply on top of it. The series' patch 2 (B2) does not (hunk at l. 1092). D v2 (patch 3) applies, and sits in the same reset-resume / system-sleep path where reviewer 3 found D v2's regression. | tested with positive controls |
| Daan Bouwman 14976888 "Add QCA Rome support for Surface Laptop 3 AMD (0cf3:e303)" (11-12; CheckPatch and GitLint fail) | btusb quirks table | Same table and same failure class as CO-22's ID request ("unexpected event 0x2005" on ROM firmware); `0cf3:e303` is not in CO-22's list | `git grep` |
| Zijun Hu 14938724 "Fix SCO/eSCO Transport_Unit_Size for HCI data path" (11-03) | `hci_enhanced_setup_sync()` | no overlap with CO-02 or CO-21 | hunk headers |
| Weihong Guan, advertising set by handle (accepted 11-11, in the tip); Piyus Kedia 14969999; Cen Zhang 14927631 | `hci_sync.c` advertising | CO-38 and CO-12 territory; CO-38 was refreshed on the tip that holds Weihong Guan's; 14927631 is the one D5 waits on | patchwork |
| bluetooth-next split `btusb.c` into `btusb_main.c` and others | btusb | every package already targets `btusb_main.c` | `git grep` |

## Mesh

Since 2026-09-01, 14 mesh-titled patches have been posted. Two kernel mesh fixes were accepted:
- Lee Jones's, after three versions;
- one by Pauli Virtanen.

Six other fixes by five authors sit at `new`: Hui Peng ×2, Jiale Yao, Cen Zhang, Igor Putko and
Wentao Liang. syzbot's "slab-use-after-free Read in mesh_send_sync" is still open (first crash
42 days ago, last 28, two patch-testing requests). Our queued mesh packages (CO-04, CO-05 + CO-26,
CO-14) would join that pile. CO-06's earlier suggestion stands as an option: one message on the
mesh transmit path instead of more single patches.

## The list as a whole (patchwork, posted 2026-10-27 to 11-14, states as of today)

- **Kernel:** 383 patches; 66 accepted, 165 superseded, 152 `new`.
- **BlueZ:** 356 patches; 79 accepted.
- **Single kernel patches vs patches in series:** 22 % accepted alone, 15 % in series. Subjects
  were classified by their `n/m`. This is a description, not a cause.
- **What gets taken:** what the accepted patches share is small, focused changes with quick
  respins (several authors went to v2–v5 within days), and replies to automated findings.
- **The list's mood:** on 11-04 a prominent kernel maintainer answered a batch of AI-assisted,
  untested patches spread over subsystems with a sharp public objection. The points were: patch
  floods, no grouping into series, no testing.
- **What that means for us:** our own queue holds about twelve kernel packages. Sent together,
  they would look like that, however well each is tested.

## Options

1. **CO-02:** v2 as layout (a).
   - Before the send day:
     - the operator's D1/D2 and the 11-14 checks;
     - a fresh `format-patch --base`;
     - the bot's CI on base and base + ours.
   - If Wentao Liang's 14942649 lands first, rebase onto it.
   - The mismatch patch and the second BlueZ test go after the pair has a reply.
2. **CO-25:** the operator decides on reply v4. It has been ready for 13 days, and the Qualcomm
   reply is 17 days old.
3. **Pace the queue:** one kernel submission at a time.
   - Start with the reviewers' choice, CO-44 or CO-38: small, single, high confidence.
   - Answer any Sashiko or Copilot finding within days.
   - Keep each package to one defect of one evidence level, as BT-24/25 and A already are.
4. **Mesh:** hold the mesh packages until a maintainer takes up any of the pending mesh fixes, or
   send the one overview message (operator).
5. **CO-43 series:** before B2 goes out, rebase it if Jens Willmer's notifier lands. D v2 stays
   held, as the 11-14 checks already say.
6. **Hui Peng's thread, gvfs:** nothing now (optional pings as in the table).

Nothing was sent or posted.
