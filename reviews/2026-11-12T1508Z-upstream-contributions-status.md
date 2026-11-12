# Upstream contributions: what was accepted, what is still waiting (2026-11-12 15:08 UTC)

A snapshot, valid at the minute in its name. Upstream state can change within minutes; the
current record stays `docs/STATUS.md` (its submission rows were last re-checked on 2026-11-01,
the gvfs row on 2026-11-07); since this check STATUS's header and the CO-02 row point here.

**Checked live for this report (2026-11-12, 15:03–15:08 UTC):** patchwork states
(`scripts/patchwork-state.py`, and the raw patchwork records in `tmp/contrib-status-20261112/`);
replies on the linux-bluetooth list, archive fetched just before 15:08 UTC, newest mail 13:35 UTC
(`scripts/lore-git-replies.py … --since 2026-10-01`); the CI's pull requests on GitHub
(`gh api`); the CI's own source (`bluez/action-ci`, `sync_patchwork.py` and `libs/patchwork.py`
on `main`); BlueZ issue #1554; gvfs issues and MRs (`scripts/cd-trace/x1-check-submission.py`);
whether CO-02 still applies to today's bluetooth-next (`git merge-tree --merge-base`).
**Taken from the records, not re-checked today:** the release lines of the accepted items
(released code does not go back; dates as in STATUS).

## 1. Accepted

| what | where | state | sent → applied |
|---|---|---|---|
| `Bluetooth: MGMT: Fix status of pending commands flushed on power off` (BT-8) | kernel | mainline v7.3; stable 7.2.11, 6.18.57, 6.12.113, 6.6.160, 6.1.191 | 09-24 → 09-29 (bluetooth-next) |
| `adapter: Fix crash on short start discovery reply` (BT-7) | BlueZ | released in 5.88 | 09-19 → 09-21 |
| `a2dp: Fix crash on NULL stream in transport_cb` (BT-7; v1 and the later v2 were both applied) | BlueZ | released in 5.88 | 09-19 → 09-21; v2 10-07 |
| `shared/mgmt: Fix notify leak in mgmt_unregister()` + its unit test (M-3) | BlueZ | released in 5.88 | 10-08 → 10-08 |
| `emulator: Free hooks in btdev_destroy` | BlueZ | released in 5.88 | 10-10 → 10-12 |
| `mgmt-tester: Add simultaneous discovery stop tests` (3 patches, BT-9's test) | BlueZ | released in 5.88 | 10-10 → 10-12 |
| `a2dp: Remove duplicate check in transport_cb` (A1) | BlueZ | released in 5.88 | 10-18 → 10-19 |
| `emulator: Avoid variable length array in send_cmd` (A2) | BlueZ | released in 5.88 | 10-18 → 10-19 |
| `ioctl-tester: Fix name of the 3-DH packet type test` (CO-34) | BlueZ | released in 5.88 | 10-28 → 10-28 |
| Stable request for `dc16388d45ec` (the QCA9377 entry, another author's commit; BT-1) | stable | released in every live line (7.2.10 … 5.10.273) | 10-02 → queued 10-02 |
| Stable backports of `96d006ae6445` (another author's fix; BT-9) to 6.12, 6.6, 6.1 | stable | released 6.12.113, 6.6.160, 6.1.191 | 10-10 → queued 10-11 |

What the accepted items have in common: each is one change with one purpose, a few lines to a
few dozen, a crash, a leak, a test or a backport, and each was applied within 0–5 days.

## 2. Sent, not accepted (or not a patch)

| what | sent | state at 15:08 UTC | the next move is |
|---|---|---|---|
| **CO-02** `[PATCH 0/3] Bluetooth: hci_conn: fix SCO connection reuse` + BlueZ `tools/sco-tester: Add SCO reconnect tests` | 10-27 17:50 +0100 | patchwork: all four **`new`, not archived, no delegate**; **no human reply in 16 days** (bot results only); an automated review (Sashiko, 10-29, on its website only) rated patch 2 "fail" because alone it does not close the race that patch 3 closes; the BlueZ test no longer applies (sco-tester was converted on 10-29, `e37f17751`); **the kernel series still applies to today's bluetooth-next** (`c9644a9257d1`; three-way, not compiled), although 19 commits since our base touch the same three files | ours: v2 (patches 2 and 3 folded, the test ported), decisions D1/D2 |
| CO-25 report to Qualcomm, `[REPORT] btusb: QCA9377 13d3:3503 on ROM firmware …` | 10-29 02:33 +0100 | Zijun Hu (Qualcomm) replied 10-29 18:42 +0800 that QCA9377 is not ROME and btusb does not support it; the evidence says otherwise (CO-25 `log.md`); **our clarifying reply is drafted and unsent for 14 days**; nothing else on the thread | ours: send or drop the reply |
| gvfs MRs **!368**, **!369** and issues **#893**, **#894** (X1, off-topic) | 11-07 03:14–03:24 UTC | all four **open**; no comment, no label, no reviewer; both MRs `MERGEABLE`, pipelines passed, heads as pushed | theirs; a polite ping is reasonable after about three weeks |
| `Tested-by` on Hui Peng's mesh_tx leak patch | 10-06 | his patch still `new` since 09-19, in no tree | theirs; nothing owed |
| `Tested-by` on 6.6.160-rc2 (CO-10) | 10-21 | 6.6.160 released 10-21; a test report needs no answer | none |
| Comment on BlueZ issue #1554 (BT-9) | 10-09 | a second affected user answered 10-14 ("will check"); nothing since | theirs; nothing owed |

## 3. The pull requests the CI closed on 11-11/12 (the e-mail)

The linux-bluetooth CI mirrors each patch series as a GitHub pull request. CO-02's two were
closed without a comment: **bluez/bluetooth-next #1009** (the kernel series) at 2026-11-11
23:58:09 UTC and **bluez/bluez #2724** (the BlueZ test) at 2026-11-12 00:36:30 UTC.

- **Who closed them:** `BluezTestBot`, the CI's account (`gh api …/issues/1009/events`, `…/2724/events`).
  No person, no review, no verdict. These pull requests are never merged in any case: patches
  are applied from the mailing list by the maintainers, and the CI pull request only carries
  the test results.
- **The rule in the CI's code:** every 5 minutes `sync_patchwork.py`'s `cleanup_pullrequest()`
  closes every pull request whose series is not among the series of the patches that patchwork
  lists as state `new` and not archived (`get_series_by_state(1)` in `libs/patchwork.py`).
- **Our series still is `new` and not archived** (patchwork records read 2026-11-12), so by that
  rule the pull requests should have stayed open. **The same sweep closed another author's
  still-`new` patch from the same day** (Stanislavs Nilovs, `hci_qca: Fix WCN3950 missing
  regulator release`, patchwork 14919536, PR #1011, closed 23:58:07 UTC). The oldest pull requests
  still open in both repositories are from 10-28. So the series of 10-27 dropped out of the bot's
  list as a group; why (a page limit or a failed query on patchwork's side, for example) is not
  established: the run's log was not read.
- **What it means for CO-02:** nothing about acceptance. The patches remain in the maintainers'
  patchwork queue as `new`. A v2 gets a new series id and a new CI pull request.

## 4. Is the worry about complexity reasonable?

Partly, with evidence on both sides.

- **For it:** everything accepted was small and single-purpose (section 1); the one kernel patch
  series still waiting (CO-02) is a three-patch race fix in `hci_conn.c` with `Cc: stable`, and
  an automated reviewer found that its patch 2 is incomplete without patch 3. CO-25's only answer
  read the report differently from what it says (a Qualcomm engineer replied that the device is
  not ROME), so its message did not land as meant.
- **Against it as the whole explanation:** silence is common on this list for anything beyond a
  trivial fix. Other authors' mesh fixes in the same subsystem have been `new` with no
  maintainer reply for weeks: Hui Peng's since 09-19, Jiale Yao's since 10-03 and Igor Putko's
  since 10-14 (patchwork, read today), Cen Zhang's since 10-12 (as of 11-01, not re-read today). Sixteen days
  without an answer is within the list's normal range, not a rejection.
- **What would help either way:** a v2 that folds patches 2 and 3 (one fewer patch to review,
  and it answers the automated finding), with a shorter cover letter; for CO-25, a short reply
  that quotes the kernel's own boot line instead of explaining.

## 5. Why this was not checked regularly

There is no routine for it. The submission rows were re-checked by hand when a session touched
them: 10-18, 10-20, 10-23, 10-28, 11-01 (all rows), 11-07 (gvfs and the BlueZ release). No
recurring check exists in the repository or in the session's schedule (the one scheduled task
found was a one-time resume on 11-01). So the last full check before today was 11 days ago,
and CO-25's unsent reply has waited 14 days. A written plan for regular checks was not found in
BRIEF, the tooling index, or the review plans of 10-19.

## 6. The registers checked against each other, and what was fixed (added later on 2026-11-12)

Every register was read: README.md, BRIEF.md (§0, the hand-off, §5, §7), docs/STATUS.md,
docs/issues.md, contributions/README.md and every dossier front page, the patch registers
(`patches/bluez/`, `patches/kernel/bt9-stable/`, `patches/diag/`), docs/sent-mails.tsv and all
5380 lines of HISTORY.md (part by outside readers working from a written brief; each finding below
was checked against its source before it was changed).

**What agreed:** the upstream facts themselves. The same commits, releases and pending items
appear everywhere; `docs/sent-mails.tsv` lists every mail any record names (27 rows) and nothing
else.

**What did not, and is now fixed** (each correction dated 2026-11-12 in place; older text kept
where it is history):
- **Released or applied, still written as pending:** the QCA9377 entry's 6.1/5.15/5.10 releases
  (README.md ×2, STATUS BT-1, BRIEF), BT-8 and BT-9 in 6.1.191 (STATUS, BRIEF, issues.md,
  `patches/kernel/bt9-stable/`), BT-7, M-3 and BT-12 in BlueZ 5.88 (STATUS, issues.md), CO-34 and
  CO-10 done (dossiers, index), E3 for `-42` "not yet booted" (`patches/diag/`), the a2dp v2 "new"
  (`patches/bluez/`).
- **Sent, still written as unsent:** CO-25 (index row and dossier said "the operator's word for
  the send" and "no replies yet"); X1 (issues.md table said "not reported anywhere").
- **Ubuntu's kernel:** `7.0.0-43` carries the entry and is in noble-updates and noble-security;
  README.md, STATUS, the CO-09 row and dossier still had "`-42` pending" or "in noble-proposed".
- **BT-16:** STATUS said "once (1 of 7 boots)" and "no recurrence"; it recurred on 11-11.
- **The 11-11 results never reached the defect register:** U8, U12, U14, U15 (the MOMENTUM 4's
  microphone silent since 10-20), U19, U20, BT-4, BT-6 ("observed once" against 15 lines in
  August).
- **A safety count overstated:** README.md, BRIEF (twice) and install.md (three times) said the
  watchdog's USB reset had "three controlled demonstrations (`EX-023`, `EX-026`)"; `EX-026`'s reset
  was not issued by this project. Now: two controlled (`EX-023`, the 2026-08-15 boot), as
  issues.md already said, and `EX-026` named separately.
- **Retractions only in HISTORY:** `EX-027`'s "the stage decides" (withdrawn by `EX-034`) and "the
  ladder destroyed nothing" are now in BRIEF §5; five HISTORY passages that later corrections
  overturned carry inline markers (the 287 withdrawal, "anonymous by construction", the
  alt-probe silence, the 9/5 reset split, the "24×" ratio, which is 28× to 41×).
- **Evidence left out:** issues.md said no exhibit bears on "a warm reboot does not recover it";
  `EX-028` and `EX-034` do. `EX-025`/`EX-029` were listed as untouched windows without their
  shutdown-probe caveat.
- **Out-of-date headers and pages:** issues.md's counts (thirteen BT, twenty U), its newest
  current-state block (10-28), BT-1's "under investigation" header, the U1–U29 heading; BRIEF's
  hand-off (11-07) and at-a-glance block; HISTORY's last chapter (11-07; a chapter for 11-07 to
  11-12 added) and its X1 block's lost quote markers; 14 dossier front pages (CO-01, 02, 06, 07,
  08, 09, 10, 11, 19, 20, 25, 34, 35, 37) now open with their current state, CO-19's with a warning
  not to install its plan's two packages; the index rows CO-02, 09, 10, 21 (dossier link), 22,
  23, 25, 35 ("since v5.7", corrected to v6.3), 38.

**Not fixed, reported:**
- No register has a row for the eight BT-16 candidates (issues.md lists them) or for U30/U31 as
  contributions; M-1 and M-2 have STATUS rows but no section in issues.md; CO-20, CO-21, CO-22
  and CO-38 have dossiers and no issue row. These need decisions about scope, not corrections.
- STATUS's long mesh rows (M-1, CO-04/05/26) still describe the 10-29 state; their send packages
  are ready and unsent; whether CO-05 1/2 still applies on top of another author's 14927631 was
  not re-checked.
- Sub-pages under each dossier's `patch/` and `send/`, and the dossiers' `log.md` files, were
  not read.

## 7. Decisions for the operator

1. **CO-02:** prepare v2 (fold patches 2 and 3 into one, port the BlueZ test, re-run the bot's CI on base and
   base + v2), or send a short ping on the v1 thread first.
2. **CO-25:** send the drafted reply to Zijun Hu (v4, `38b496b`), or let it rest.
3. **gvfs:** wait; a ping after about three weeks (around 11-28).
4. **A regular check:** one script that runs every check in this report and prints only changes,
   run at the start of each working session (or on a schedule).
