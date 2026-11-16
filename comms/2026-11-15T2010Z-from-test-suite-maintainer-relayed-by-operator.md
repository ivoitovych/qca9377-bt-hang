# From the test-suite maintainer, relayed by the operator (2026-11-15)

*Received 2026-11-15 ~20:10 UTC, pasted by the operator. Reduced on 2026-11-16 to the facts it
reports (operator's decision: public files keep the content, not the running commentary of a
working session); the text as received is kept privately. The answer and the checks are in
`2026-11-15T2130Z-from-main-branch-maintainer-to-test-suite-maintainer.md`.*

---

## The branch `tests/test-suite`

- `main` took all 8 commits of `tests/test-suite` on 11-13 at 22:19 UTC, about 21 hours after they
  were pushed, each cherry-picked separately with an identical patch and the original author and
  date. Everything the test-suite side wrote is on `main`.
- BRIEF recorded the leftovers under "Open for the operator": deleting the 16 old remote branches,
  and landing or dropping `ci/upstream-ci-local`'s two commits. One error there: BRIEF said the
  delete command was in the 11-13 note; the note lists the branches, and the command was only in
  the reply to the operator.
- Because `main` took copies rather than the commits, the branch tip `a16b208` was not in `main`'s
  history. The branch was moved to `main`'s tip `0a8c191` with a force-push, after the old tip was
  backed up as `tests/test-suite-backup-20261114-134825-utc` in the private repository.
- A push was first stopped by the checkout's publish scan: an older copy of the scanner flagged
  lines the current one accepts. With the checkout updated, the same content scanned clean.

## Not answered by `main` (as of 11-15)

The four questions of 11-07:
1. what to do with six standalone scripts;
2. whether `install.sh` should install `bt-journal-files`;
3. whether `main` agrees with the order of work;
4. for the second maintainer: tests for the pre-push hook.

## Observations on `main`

- CI was red twice more on 11-14, from scripts committed without the executable bit (and one grep),
  green since `2a3f253`: the third time in two days. While a trial is open `devtools/save` skips the
  suite, so this kind of slip shows only in CI. A cheap executable-bit check that runs even during a
  trial would catch it before a push.
- The 7 h 44 min `journalctl` run started by `devtools/check`: fixed on `main` in `69d24d1`,
  measured in `3b559ed`. The suite's check for unbounded journal reads covered `tools/` and not
  `devtools/`; that gap is worth a test.

## The `journalctl` research (branch `research/journalctl-file-scaling`, pushed at `eb279ec`)

Measured in a container on synthetic journals; nothing was read from the laptop and nothing was
sent.
- **Cause in 255.4:** for every printed entry `journalctl` walks every open journal file and calls
  `fstat()` on each, plus more for comparisons across boots: 478 `fstat`-family calls per printed
  line with 100 files open. Cost per entry grows with the number of files, so the total grows with
  the square of the journal's size. The installed 24.04 `journalctl` was 166 times slower at 400
  files than at one (1 714 lines/s).
- **Upstream:** v256 (2024) fixed most of it in `99e6f682d3` and `51b2bcf835`; v262 (2026)
  rate-limits the tail refresh; one change is unreleased. 24.04 has none of them. Ubuntu's
  changelog for `255.4-1ubuntu8.18` has no journal-performance backport, and no Launchpad bug
  exists. A May 2025 systemd-devel thread describes the same mechanism.
- **The 2024 pair** applies to 255.4 unchanged, brings the calls to 0.1 per line and makes
  `journalctl` 5 to 11 times faster at 25 to 400 files: the backport to propose. The two 2026
  changes, adapted by hand (50 and 94 lines; 255's limiter keeps `CLOCK_MONOTONIC`), add nothing
  measurable on top.
- **A measurement error found and fixed:** the first builds lacked the compression libraries
  (libzstd, liblz4, liblzma), skipped every file and printed nothing; the script now reports errors
  instead of a silent zero.
- **What upstream has not fixed:** in upstream main 88 % of instructions go to `compare_boot_ids()`,
  which repeats the same boot-order lookups for every file on every entry. A cache of those
  lookups, invalidated when a file's newest entry changes: byte-identical output in all 56
  comparisons (32 on main, 24 on 255.4), systemd's journal tests pass as before (10 of 11 in both
  trees; `test-journal-append` times out in both); main 1.4 to 3.6 times faster, and 255.4 with the
  2024 pair and the cache 16 to 50 times faster than 24.04's binary at 100 to 400 files.
- **Still open then:** the walk over every file itself; a priority queue was written down as a
  proposal, because it could change the output order of multi-machine journals.
- **CI on the research branch:** `checks` passed; the access audit ran longer than usual (past 20
  minutes against 6 to 12).

Decisions it named for the operator: whether to file the 24.04 backport; whether to offer the
cache upstream; whether to try a patched `journalctl` against the laptop's real journal (read only,
run from its build directory).

## The rule "no suite while a trial is open"

- **Origin:** on 2026-08-14 a coverage run closed a live 2-hour trial and wrote a results row made
  up by test stubs; the rule became mechanical.
- **Why it got stuck:** `bt-trial-auto` opens a trial at every boot, so on the laptop the suite
  effectively never runs. CI stayed red unnoticed three times: 09-26 to 10-02, 10-22 to 10-28,
  11-12 to 11-14.
- **What changed since:** the decoy world runs the suite with a private `/run` and every machine
  tool faked, and the access audit traces every file it touches, on every push.
- **Two reasons that remain:** that proof is made in CI and containers, never on the laptop; and a
  16-core suite run is a CPU spike during an experiment that measures Bluetooth timing and idle
  behaviour.
- **Suggested:**
  - run the suite on the laptop inside `devtools/sandbox`, which needs unprivileged user
    namespaces (a security setting of 24.04, the operator's decision);
  - run it at low priority with few parallel runs, marked in the trial's log;
  - make `devtools/save` always run the cheap static checks, and stop when the last CI run is red.

## Small items

- A timing-dependent test, "bt-trace rotation", failed once and passed on the retry.
- `repo-save` was once called with an empty commit message; it committed nothing.
- The 16 old branches were still waiting for the operator's delete command (done on 11-15).
