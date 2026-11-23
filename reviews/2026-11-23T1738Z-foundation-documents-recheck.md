# The foundation-documents review rechecked on `main` at `418331c7`

**Follows** [`2026-11-23T0353Z-foundation-documents-review.md`](2026-11-23T0353Z-foundation-documents-review.md)
(findings FD-01 to FD-21, on `main` at `7bb47fc6`). **Read:** `main` at `418331c7`
(2026-11-23 08:00 +0100), eight commits later. **How:** one lookup per finding on the tip, and
the first 45 lines of the new hand-off block. The rest of the eight commits (47 files, the
regenerated packages, the new review files) was not read. Nothing was run.

## Result

`BRIEF.md` has a **fresh hand-off block dated 2026-11-23** (commit `b1d7f601`); the block of
11-14 was moved to the end of `HISTORY.md`. This is what the review's last paragraph asked
for, and it removes the findings that sat in the old block. Nothing on `main` refers to the
foundation-documents review, so the fixes were made independently of it.

| finding | now |
|---|---|
| FD-15 (the hand-off's "Patch ready" list named CO-04, CO-05, CO-12) | **gone**: the new block says "Overtaken by others' applied fixes, not to be sent: CO-04, CO-05 1/2, CO-06 and CO-14 … CO-12", and gives a send queue (CO-38's kernel patch, CO-44, CO-22's request v4, the btusb series, CO-26) |
| FD-16 (CO-14 "confirmed" as a new finding) | **gone** with the old block |
| FD-17 (the 11-14 outside-review document as the one to share) | **gone** with the old block |
| FD-19 ("Last updated: 2026-11-16") | **fixed**: 2026-11-23 |
| FD-20 (the branch list of 11-15; the two port commits) | the sentence is gone from the hand-off; the ancestry of `8b71499` and `a56141e` was not looked up again |
| FD-11 (`BRIEF.md`, state block: v2 as "the fold of 2 and 3 … possibly the mismatch patch") | **not addressed** |
| FD-12 (state block: "Every other authors' mesh fix is still `new`") | **not addressed** |
| FD-18 (state block: "CO-04's independent fix" as an open investigation; the reply on Jiale Yao's patch as an open decision, `:111`) | **not addressed** |
| FD-21 ("the coordinator's choice", "the five tracks") | **not addressed** |
| FD-13, FD-14 | not looked up again |
| FD-01, FD-02, FD-04, FD-05, FD-09 (`README.md`) | **not addressed**: the heading is still "Current direction — 2026-11-15" (`:151`), the Hui Peng patch is still "pending", "four things" still names three |
| FD-03, FD-06, FD-07, FD-08, FD-10 | not looked up again |

## Notes on the new hand-off block (lines 171 to 215 read)

- It agrees with the upstream check of 2026-11-22 on every point that check made: the five
  overtaken items, CO-26 standing alone, CO-35's 7.3.y queued and the rebase onto the three
  queued sibling patches, CO-22 still needed. It adds a rule that the check's own correction
  suggests: "check 'applied or not' in the tree, never in patchwork's state alone".
- It reports work that goes beyond anything this review saw: CO-38 and CO-44 tested on
  bluetooth-next and on 7.3.5, 6.18.64, 6.12.118, 6.6.162 and 6.1.192; the btusb fixes
  regenerated as one three-patch series on `cf357cfc025e` with 105 QEMU runs. Those claims
  were not verified here.
- **New, Low (the rule of `BRIEF.md` §7 on identifiers):** the new block elides directory
  names again: `CO-38-…/send-20261123/`, `CO-44-…/send-20261123/`, `CO-43-…/series-20261123/`,
  `reviews/2026-11-23T0404Z-…`. These are the paths a sender copies.
- The state block above the hand-off is unchanged, so the file still has two "current" blocks
  that disagree on the mesh items and on CO-02 v2 (FD-11, FD-12, FD-18).

*Written on 2026-11-23; not edited afterwards.*
