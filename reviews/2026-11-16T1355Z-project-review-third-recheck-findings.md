# The whole-project review of 2026-11-15: findings of the third recheck

*Received 2026-11-16, relayed by the operator. The reviewer verified one commit, `d331c8e`, which
answers the privacy section of the second recheck. The recheck page is on a separate branch
(`17f8ac67`). This page keeps the findings only (2026-11-16: public files keep a review's
content, not its running commentary).*

---

**What the commit did, confirmed on the files:**
- The two stored messages on `main` are replaced by files that keep only the findings.
- CO-46's package builder reads a private word list kept outside the repository.
- `devtools/repo-scan` refuses added lines that match that list, at save and at push.
- The newest `HISTORY.md` chapters are reworded, and so is one bullet in an older block.
- One evidence note's home path is replaced in two of three places.

**Still open:**
- The replaced text is still in the history of `main`. Removing it for good needs a history
  rewrite, which was not done.
- The new scan protects only a machine that has the private list. Elsewhere, including CI, it
  prints a note and passes. It had no test yet.
- Older text was left on purpose, as a separate decision:
  - older `HISTORY.md` blocks;
  - lines in `BRIEF.md`, `docs/STATUS.md` and `contributions/rd-2026-11-14.md`;
  - the four places of the review's P-03;
  - the pasted text in `comms/2026-11-15T2010Z-…`;
  - the work-area path in 2,713 files;
  - an older package builder (`contributions/review-2026-11-02/build/build.py`) with a public
    word list.
- One home path remains in `evidence/sessions/20261116-002107-shure-paired-in-handsfree-no-codec-row/NOTES.md:46`.
- Everything outside privacy stands as listed in the second recheck.

**A decision for the operator:** whether the reviewer's branch should be deleted once its findings
are taken, or rewritten (a force-push) to drop the quotes in two of its earlier commits.
