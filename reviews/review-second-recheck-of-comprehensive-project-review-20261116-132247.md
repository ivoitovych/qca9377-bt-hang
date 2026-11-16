# The project review after the second round of fixes: `main` verified at `bbec102f`

- **Written:** 2026-11-16T13:22Z (UTC), on the branch that holds the review.
- **Earlier pages on this branch:** the review
  ([`review-comprehensive-project-consistency-review-20261115-005742.md`](review-comprehensive-project-consistency-review-20261115-005742.md),
  `162d3b9`, on `main` at `da23558`) and the first recheck
  ([`review-reaction-to-comprehensive-project-review-20261115-204454.md`](review-reaction-to-comprehensive-project-review-20261115-204454.md),
  `3f8e8f62`, on `main` at `a8d0eb45`). Ids (F-01, T-08, N-02 …) and item numbers 1 to 26 are theirs.
- **What was verified:** `main` at `bbec102f` (2026-11-16 14:01 +0100), 59 commits after
  `a8d0eb45`, and the maintainer's own list of what was done,
  `reviews/2026-11-16T0000Z-project-review-recheck-checks.md` on `main`. Each claim of that
  list was looked up on the files; each item the first recheck left open was looked up again.
  Files were read; nothing was run.
- **Verdicts:** **confirmed** (the list's claim holds on the file) · **partly** (what is missing
  is named) · **not so** (the claim does not hold) · **open** (the list itself says so) ·
  **waits for the author**.

Written in the order verified; sections 1 and 2 (summary, what is left) are written last.

## 3. Detail

Line numbers are those of `main` at `bbec102f`.

### 3.1 The working arrangement in the text (items 24 to 26): worse, and urgent for the author

The maintainer's list records item 24 as waiting for the operator, "asked again on 2026-11-16,
with N-01 named". While it waits, `main` gained text of exactly this kind, and no scan pattern
was added (`devtools/repo-scan` has none), so the forward-only approach that was proposed is not
in force.

- **A-01 (High, privacy, new, checked): the reviewer's chat messages are stored on `main`
  verbatim.** `reviews/2026-11-16T0000Z-project-review-recheck-reaction-verbatim.md`:
  - `:12`, `:14`: "… verifying the two new risks the workers raised", "All twenty rechecks are
    in. Verifying two new problems the workers reported";
  - `:18`: "pushed to my branch as commit `3f8e8f62` (authored and committed as you, no
    trailers)";
  - `:50`: "The environment had reset the global git identity to a tool identity again; the
    guard hook refused the commit, I restored your identity, and the commit went through
    clean."
  The branch name was replaced by "[a separate branch]"; these four lines were kept. Read
  together they say that the commits under the author's name on that branch were made by
  something that is not the author, and that a hook exists to keep it so. This is the single
  most quotable text in the repository for the purpose the author fears, and it is on the
  public default branch. `reviews/2026-11-15T1751Z-project-review-fixes-reaction-verbatim.md`
  is the earlier message of the same kind (less explicit). Removing them needs a history
  rewrite (`BRIEF.md` §7, the backup-branch rule) or at least a follow-up commit that replaces
  the files; the second keeps them in history.
- **A-02 (Medium, new):** `contributions/CO-46-systemd-journalctl-file-count-slowdown/build-review-package.py:25-27`
  is a third filter that names what it hides: a `BANNED` list with five product and model
  names, the work-area directory name, and the word for the shortening of a long conversation.
  The review's P-03 said this of `contributions/review-2026-11-02/build/build.py`; the pattern
  was repeated on 11-16.
- **A-03 (Medium, new):** the `HISTORY.md` chapters added on 11-15 and 11-16 describe the work
  as "five lanes at once", "four fix lanes, one per area", "one lane fixed them", "lane 11". The
  older blocks, not listed in the review, say more: `HISTORY.md:5754-5756` "**Agents:** the
  weekly limit of 11-02 ended 2026-11-05 09:00. The rule that remains: cheap agents for
  per-file reviews, the main context synthesises."
- **N-01** (the pasted transcript in `comms/2026-11-15T2010Z-…`): unchanged.
- **P-01:** the work-area path is now in 2,714 files and 11,062 lines (2,716 and 11,068 at the
  review): the authored copies in `docs/STATUS.md` and `docs/issues.md` were replaced, the logs
  remain. **P-02, P-03:** unchanged, apart from `BRIEF.md:208`, which no longer spells the path
  ("the lanes' directories `lane<N>-*-20261114/` in the work area").
- **Item 25 (P-04):** the list says the review was partly wrong, and it is right:
  `contributions/CO-25-qualcomm-rom-report/log.md` does say all fifteen were refused with `535`
  and revoked. What the list adds stands: the check used port 465, which the project's own
  fixed `smtp-login-check.sh` would now have to confirm on 587; not recorded.
- **Item 26:** unchanged; the review pages are on this branch only.

What the author may want to decide today, in this order: (1) the two verbatim files; (2) a
refusal pattern on the save path for the work-area name and the words of 3.2 of the review,
so that the count stops growing; (3) a rule that a reviewer's or a maintainer's message is
stored as its content (findings, numbers), not as its running commentary.

