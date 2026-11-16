# The project review: `main` verified at `ea994867`

- **Written:** 2026-11-16T14:22Z (UTC). It follows the second and third recheck pages on this branch
  ([`review-second-recheck-of-comprehensive-project-review-20261116-132247.md`](review-second-recheck-of-comprehensive-project-review-20261116-132247.md),
  [`review-third-recheck-of-comprehensive-project-review-20261116-135309.md`](review-third-recheck-of-comprehensive-project-review-20261116-135309.md));
  item numbers and ids are theirs.
- **Verified:** `main` at `ea994867` (2026-11-16 15:18 +0100), 21 commits after `d331c8e9`,
  115 files. There is no item-by-item list for this round on `main`; the commits were taken as
  the claims.
- **How:** every item of "What is left" on the second page (4 to 24), every new item of that
  page (B-01 to B-10) and every point of the third page was looked up on the tip, about seventy
  point checks, and the diffs of the code fixes named below were read. The rest of this round's
  diff (about 660 added lines in code and tests) was not read line by line. Nothing of the
  project was run; one `find` expression was tried in a scratch directory.

## 1. Result

This round answers nearly everything that was left. Of the items listed on the second page,
the following are done, each confirmed on the file:

- **Packages (items 4 to 8):** the outside-review document carries a note that it is the state
  of 11-14, names the one checksum that no longer matches and points at the table (it was not
  regenerated, and says so); CO-35's `COPIED-FROM.md` covers the covers; `BRIEF.md` and
  `README.md` no longer say CO-02's cover is to do; CO-30's README says its base path is not in
  the repository; the 11-15 status report has a dated note; `HELD.md` now says the cover quotes
  the first run; CO-43's `A-review-fixes-20261114/` has `NOTES-FOR-OPERATOR.md`; CO-38's README no
  longer says "not shown"; CO-11's front page; CO-46 has a row in "What to send" ("under review,
  not ready to send") and its README says where its data is.
- **Code (items 9 to 11, B-01 to B-06):** `tools/verify-restored.sh` reports a loaded `N` as
  information; `tools/bt-backup-journal` does not retry a refused re-archive; the keeper of
  `tools/bt-ui-capture` refuses unless the script, its directory and the checkout are owned by
  root and closed to others, in the tool and again in the timer's own command (the expression
  was tried: a group-writable directory and a foreign owner are both refused); `guard()` accepts
  a closed window; `tools/lib/journal.sh` (count and first); `tools/bt-trial` (a budget on the
  reads before the row); `scripts/ci-local.sh` (a failed functional build is NOT RUN);
  `scripts/bt17-provoke.py` (a vanished device is a failure); the stable matrix takes its device
  and branches; CI examines the newest 50 commits after a forced update; `repo-scan --range`
  judges the push target; the allow-list is narrowed to named hosts and unit names;
  `install.sh --tools-only` writes no first-install stamp; `tools/bt-incident` records a missing
  timeline in the manifest.
- **Tests (item 21):** the wording check has a test with a scratch list (planted phrase
  refused, clean addition passes, empty list refused, missing list says so, `--all` does not
  apply it); eight more machine commands declared; the default device in a staged install; the
  light mode's shell filter in the suite.
- **Documents (items 13 to 20):** `BRIEF.md` (`:145` rebases, `:229` "not true after 11-14",
  `:326` the early reset, §9.2's name); `docs/STATUS.md` (U8's condition, the CO-03 hash,
  "five patches", truncated hashes expanded where the tree has the full value: 4 left);
  `docs/issues.md` (BT-9, BT-10, U8, U12, U13 and U29 owners, the closing section dated, 2
  truncated hashes left); `docs/investigation-plan.md`; a "State as of" line on the eleven older
  `docs/` files; the bot time given the same way in three places; `reviews/README.md`;
  `README.md`'s branch paragraph; the exhibits index now says what supersedes EX-093 and EX-086;
  notes for E3 #6 to #11; `HISTORY.md`'s early-reset note and milestones.
- **The third page:** the pasted message in `comms/2026-11-15T2010Z-…` is reduced to the facts
  it reports (no first-person line left); the 11-02 package builder no longer carries a public
  word list; the last home path under `evidence/` is gone; CO-25's fifteen passwords were
  re-checked on 11-16 (item 25).

## 2. What is still open

**Small, in files (all Low):**
- `contributions/CO-23-one-off-events/patch/send/send.sh` is still there beside its
  `SUPERSEDED.md`: a working send script in a directory that must not be sent from.
- `BRIEF.md:254` (the D1/D2 gloss), `:839` (`815e7378…b90b72`), `:595` (the two lessons files
  as the source of every rule of §8a); the hand-off block is still the one of 11-14, with
  corrections, and the file says so (`:148`).
- `docs/issues.md:1552` keeps "that test is next" in front of the note that answers it.
- `docs/sent-mails.tsv`: row 7 and the three hashes of address-elided copies, unchanged.
- `patches/bluez/README.md`: the heading still says UTC above the note that doubts it;
  `patches/diag/README.md`'s body.
- The keeper checks three paths; the other files that root's units run from the checkout
  (`scripts/bt-ui-atspi.py`, `tools/lib/`) and the directories above the checkout are not in
  the check. To look at on the machine.
- CO-46's data is on the branch `research/journalctl-file-scaling`, not on `main`; the README
  now says so. Whether it is ported is a choice.

**By design, and stated on `main`:**
- The wording check passes with a note where the private list is absent, and CI does not run
  it. Its comment still says it "does not pass silently"; under `--quiet` it prints nothing.
- One place for "current" (S-12).

**The author's decisions (unchanged):**
- The removed messages are in the history of `main` (two commits touch the deleted file).
- Older text on the tip: the work-area path in 2,712 files and 11,057 lines; `HISTORY.md` 15
  lines, `BRIEF.md` 3, `docs/STATUS.md` 9, `contributions/rd-2026-11-14.md` 30; the four places
  with a product name or a tool's path (`contributions/CO-25-qualcomm-rom-report/log.md:273`,
  `scripts/user-audio-streams.sh:11`, `docs/STATUS.md:122`,
  `reviews/2026-10-28T0300Z-documentation-alignment.md:33`); `/home/i/` in 36 lines under `docs/`
  and `results/`.
- This branch: delete it, or rewrite it, once its pages are no longer needed (third page, 2.3;
  `reviews/2026-11-16T1355Z-project-review-third-recheck-findings.md` on `main` records the
  question).

**To confirm on a machine or a full clone (unchanged):** whether `8b71499` and `a56141e` are
ancestors of `main`; `scripts/sco-ledger.sh` on a boot without a call.

## 3. Standing of the review

Of the review's 15 High findings, 11 are fixed, 1 needs the one command above, and 3 are the
author's decision on older text, for which the forward measure (the scan, the reduced
messages) is now in place. No Medium finding that concerned code, a package to be sent or a
safety instruction is known to be open. What remains is the short list in section 2.
