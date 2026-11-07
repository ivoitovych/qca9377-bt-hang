# From the main branch maintainer to the test-suite maintainer — CI red since 2026-10-22

**Short:** `checks` was red on every push from `4ee379d` (2026-10-22) to `a9b276e` (2026-10-28),
about 65 pushes, and nobody read it: a trial was open all week, so `devtools/save` ran no suite and
said "CI will run it on push" each time. Two causes are fixed on `main`; one is yours to close.

## Fixed on `main` (2026-10-28)

1. **The install step, from `4ee379d`:** `apt-get install` without `apt-get update`; the runner
   image's index named `systemd-journal-remote 255.4-1ubuntu8.17`, which the mirror no longer
   served (`Err:3 … noble-updates/universe amd64 systemd-journal-remote`), exit 100. Every install
   step in `checks.yml` and `access-audit.yml` now runs `apt-get update -q` first (`deaafab`).
2. **Eight invariants, from the journal work of 2026-10-23 (ours):** the three seams it added
   (`BT_JOURNAL_SRC`, `BT_JOURNAL_FILES_DIR`, `BT_JOURNAL_DIR`) were neither in
   `tests/system-resources.md` nor declared for the run. Undeclared, `BT_JOURNAL_DIR` fell back to
   the runner's real `/var/log/journal/<machine-id>`, so `lib/journal.sh`'s fast kernel path ran in
   tests and called `journalctl --list-boots` before each `-k` read; `bt-window`'s bounded-read test
   then counted three unbounded reads (its headline and six detail lines). Now catalogued, and
   declared next to `BT_ARCHIVE_DIR` (`BT_JOURNAL_DIR` to a path that does not exist, so the fast
   path steps aside at once). The suite passed on `deaafab`; the inline-differ exclusion moved +10
   by content (`14ae3af`).

## Yours, if you agree: `tools/bt-journal-files` has no suite tests

`devtools/test-comprehension --min 75` fails on `14ae3af`: `tools/bt-journal-files` scores 0%
(asserts 0, refusals 0/2 at lines 42 and 46, seams 2/4 with `BT_JOURNAL_FILES_BUDGET_GB` and
`BT_JOURNAL_FILES_FREE_MIN_GB` never set, branches 0/60). Its twelve cases exist, outside the suite:
`devtools/test-bt-journal-files.sh` (a fake journal directory under `tmp/`, `journalctl` stubbed on
`PATH`, a corrupting `zstd` wrapper for the verification case; prints `PASS`/`FAIL` and "passed N,
failed M"). I did not move them into `tests/run-tests` myself: the suite cannot run here while a
trial is open, and wiring a script that needs a real `zstd` and writes under `tmp/` into the decoy
world is your judgement, not something to try blind on CI. Until then CI stays red on that one floor.

The full account of the week's documentation drift, of which this was one cause:
`reviews/2026-10-28T0300Z-documentation-alignment.md`.
