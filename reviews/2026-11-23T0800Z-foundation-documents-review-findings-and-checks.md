# The foundation-documents review: each finding checked and answered (2026-11-23)

**Reviews answered:** [`2026-11-23T0353Z-foundation-documents-review.md`](2026-11-23T0353Z-foundation-documents-review.md)
(FD-01 to FD-21, read on `main` at `7bb47fc6`) and its recheck
[`2026-11-23T1738Z-foundation-documents-recheck.md`](2026-11-23T1738Z-foundation-documents-recheck.md)
(on `main` at `418331c7`, one new finding). Both are by the same outside reviewer and are copied here
unchanged from the research branch.

The reviewer read `7bb47fc6`. The hand-off was replaced the same morning in `b1d7f601`, independently of
this review, so several findings were already fixed on the tip. Each finding was checked on the current tip
before anything was changed. The reviewer's opinions are weighed, not taken as orders.

| finding | checked on the tip | outcome |
|---|---|---|
| FD-01, `README.md` "four things" names three | true | **fixed:** "three failures that look identical to a user", with the working link named apart |
| FD-02, Hui Peng's patch "pending" | true. `1d7a52778858` has commit date 2026-11-19 in bluetooth-next (`git log`); the review's 11-18 is not the commit date | **fixed:** "overtaken … in bluetooth-next since 2026-11-19", and the patch stays `new` |
| FD-03, the E1 row's exhibits read as a sum | true | **fixed:** `EX-058` carries the 58; `EX-056` and `EX-055` are named as not added |
| FD-04, the heading dated 11-15 | true | **fixed:** "Current direction — 2026-11-23", with a new first bullet for the ready send queue |
| FD-05, "queued on 2026-11-22"; sibling patches unnamed | true | **fixed:** "seen queued … on 2026-11-22", with the three sibling patches for 6.18, 6.12 and 6.6 named |
| FD-06, `btusb.c` only | true | **fixed:** `btusb_main.c` named for bluetooth-next |
| FD-07, `7.0.0-44` in noble-proposed | not re-read here | **left:** nothing depends on it; the paragraph names published versions on purpose |
| FD-08, "under review" for a series with no reply | true | **fixed:** "sent, with no maintainer reply" |
| FD-09, the pre-cause formulation of BT-1 | true; the quoted block is held identical by a test | **fixed** around the block, not in it: one sentence says it is the symptom, written before the cause, and names the cause |
| FD-10, the 16 branches deleted | confirmed by the reviewer | no change |
| FD-11, `BRIEF.md` CO-02 v2 as "the fold of 2 and 3" | true | **fixed:** marked correction of 2026-11-23 with the current candidate and its path |
| FD-12, "every other authors' mesh fix is still `new`" | true | **fixed:** struck, with what `1d7a52778858` overtakes |
| FD-13, E3 bullet in the present tense | true | **fixed:** E3 retired; the check kept as a safeguard |
| FD-14, lore over git | checked from this machine: `scripts/lore-git-message.sh` reached the archive and searched its newest 300 mails, with no 403 | **noted** in `BRIEF.md`: re-checked 2026-11-23; try it once on a new machine |
| FD-15, FD-16, FD-17, FD-19 | already gone with the hand-off of `b1d7f601` (confirmed by the recheck) | the 11-14 document is now also named as outdated in the day's records |
| FD-18, CO-04 as an open investigation; a reply on Jiale Yao's patch | true | **fixed:** both struck, with "overtaken by `1d7a52778858`" |
| FD-20, `8b71499` and `a56141e` ancestry | `git merge-base --is-ancestor` on the full clone: both exit 0 | settled: both are on `main` |
| FD-21, "the coordinator's choice", "the five tracks" | true | **fixed:** "the project's choice", "the five work lines" |
| Recheck, new: directory names shortened with `…` in the hand-off | true (five places, plus three review names) | **fixed:** every path written in full; the send queue's list order also repaired (two paragraphs had split items 2 and 3) |

**Cause, as the review says (S-12):** the state block and the hand-off are both "current" and were corrected in
place, so a correction reached one and not the other. The state block's four stale lines are now corrected and
marked. Rewriting the whole state block is a larger edit, left for a planned documentation pass.
