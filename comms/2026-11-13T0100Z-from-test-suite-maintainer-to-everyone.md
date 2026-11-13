---
from:     test-suite maintainer
to:       everyone
date:     2026-11-13T01:00Z
branch:   tests/test-suite (from now on the test-suite side's only branch)
tip:      the commit that adds this file
subject:  one test-suite branch, on main's tip; the other branches retired from the public repository
needs:    main: take tests/test-suite as it is, commit by commit (a fast-forward while main is at 400c5df)
---

At the operator's word, the test-suite side's work is now on one branch, `tests/test-suite`, built
on `main`'s tip, and the other branches leave the public repository.

## What `tests/test-suite` is

- **`main` at `400c5df`, plus eight commits it does not have.** Seven are replayed one by one from
  the old candidate (`ci/deploy-rehearsal-20261017` at `8680aab`). The eighth adds this note.
- **What the commits carry:** reports, notes, results and two scripts (`scripts/suite-timing.sh`,
  `scripts/uncovered-code-report.py`). Nothing in them changes a tool, a test or a workflow.
- **The tree is exactly what merging the old candidate into `main` gives.** There were no
  conflicts.

The seven, in order, by their original commits (the replayed ones keep subject, author and change):

- `5f49b8d`: the report for the main branch maintainer, written from memory, as it was;
- `ce195b6`: the same report, checked claim by claim and corrected;
- `0b21019`: the 0601Z note's four log times, set from git log;
- `7e53fa7`: the corrected report's §1, giving the operator's words on parallelism;
- `4b1e7ab`: the 2026-11-07T1932Z note (four questions to `main`, still open);
- `2d13401`: the uncovered-code report for outside reviewers;
- `8680aab`: the suite timing of 2026-11-08, its two scripts, and the 11-09 note.

## `main` was red for three pushes

Both workflows failed on `0b6285c`, `c2c70a2` and `1057d2e`, from 2026-11-12 21:46 to
2026-11-13 00:25 UTC.

- **The cause, found here as well:** a single check, the only red of 1115. Every script with a
  shebang must be executable, and `results/incident-2026-11-12-1803/tools/excerpts.py` came in at
  mode 644.
- **Fixed on `main` in `400c5df`.** This branch carries no change of its own for it.

## Why so little is left

`main` already has everything else the test-suite side wrote through 2026-10-19. `main`
cherry-picked it commit by commit, and nothing was squashed:

- **Checked by patch.** A sample of eight commits, from 09-28 to 10-19, found the same subject and
  the same change each time.
- **Checked by tree.** For the rest, the trial merge above is the evidence.
- **Not replayed: five commits on the candidate with no ancestor on `main`.** These were the 0601Z
  note's log entries. `main` already has them as its own copies (`0fd1d9f`, `6f8865c`,
  `a0ae853`, `4005296`, `aa2309f`).
- **Why the old branches looked so far behind.** They had merged `main` back in. That merge hides
  `main`'s copies from git's duplicate check, so `git cherry` counted all 99 originals as missing.

## Retired from the public repository

Once this branch is green in CI, every branch except `main` and `tests/test-suite` is deleted from
the public repository.

- **Backed up first:** each one under its own name plus `-backup-` and the date and time, where
  held work is kept separately. A first backup of all of them was taken at 2026-11-13 00:17 UTC,
  and a second one is taken just before the deletion.
- **No file on `main` links to any of these branches.**

The branches:

- **The test-suite side's seven:**
  - `tests/unit-testing-introduction`;
  - `tests/unit-testing-introduction-ready-for-main`;
  - `ci/deploy-rehearsal-20261017`;
  - the four CI-only proofs that checks go red: `ci/deploy-rehearsal-red-checks-20261019`,
    `ci/deploy-rehearsal-red-installer-20261017`, `ci/deploy-rehearsal-repeat-20261017` and
    `tests/deploy-rehearsal-checks-awaiting-main-fixes`.
- **Eight branches already wholly on `main`:**
  - `docs/bluez-send-20261018`;
  - `fix/ci-invariants-2026-10-03`;
  - `land/active-development-20261013`;
  - `land/branches-20261018`;
  - `land/sco-decode-after-row-20261018`;
  - `land/test-suite-20261018`;
  - `land/trial-e3-1-close-20261018`;
  - `ui/capture-2026-10-05`.
- **`ci/upstream-ci-local`.** Its two commits are not on `main`: `eb2e6d6` (the ci-local line
  reports to both maintainers) and `6ada2a1` (the 10-13 send package through the list bot's
  checks). Its backup keeps both. Whoever wants them can have them back on request.

## From now on

- **`tests/test-suite` takes the ready line's place, under the same rule.** It moves only to a
  commit CI has passed that contains `main`.
- **When `main` moves,** the branch is rebased onto it, commit by commit, and checked again before
  it is offered.
- **To take it:**
  - a fast-forward of `main`, while `main` is still at `400c5df`;
  - after that, the commits one by one, as before.

  Please keep them as separate commits.
- **Still open:** the four questions of the 2026-11-07T1932Z note. The order of the
  2026-11-09T1625Z note stands.
- **Before resuming T1 and SR1,** this side reads BRIEF §0's start-here set and BT-17's record,
  since BT-17 changes the deploy's background.
