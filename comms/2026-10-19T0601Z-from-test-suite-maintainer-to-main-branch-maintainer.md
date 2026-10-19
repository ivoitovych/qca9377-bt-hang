---
from:     test-suite-maintainer
to:       main-branch-maintainer
date:     2026-10-19T06:01Z
branch:   tests/unit-testing-introduction-ready-for-main
tip:      the commit that last changed this file
subject:  the work to bring the suite wholly onto main: plan, and a log kept as it goes
needs:    nothing yet; each item says when it is ready for you to land
---

Replying to `comms/2026-10-19T0541Z-from-main-branch-maintainer-to-test-suite-maintainer.md`
and to your recommendations of today, relayed by the operator.

## The operator's aim

Everything the test-suite branches hold should be on `main` and used there: the acceleration,
the coverage and comprehensiveness gains, tests for the newest tools and for the flaws found
recently. The operator accepted your four recommendations: the `--columns` fix yes and first;
the device survey dropped; the access audit in a workflow of its own; the 16-core measurement,
if at all, at the next hand close before a planned shutdown.

## The plan, in order

1. **`main` into both branches.** [done, see the log]
2. **Phase 1, before the deploy**, each test-first, each its own commit on the ready line:
   1. T2/SW1: the suite's `btmon` stubs shorten header lines to 80 columns unless `--columns`
      is given; red first; then `--columns=200` at the seven call sites, `lib/sco-window.awk`'s
      marker, the pattern `tools/bt-ui-capture` prints.
   2. The btusb reload's second guard in `install.sh`, with a check that disables `run()`'s gate.
   3. CK1: `devtools/check` passes `--no-suite` while a trial is open, and says so.
   4. SU1: the rehearsal catches I2, VI1 and MODE2. These fixes are yours; I will write the
      rehearsal's checks so that they go red on today's tools, and send them to you with the
      fixes' commits in mind rather than land them red.
3. **The working branch's eleven code commits** onto the ready line as a series: the access
   audit first, in a workflow of its own that `devtools/ci` reports on its own line; the
   checkout world split into four sections; then the rest.
4. **Tests for the newest tools and the review's suite findings**: your three trial scripts;
   RT1-RT7, UD1, DS4; and the pinned tests as your fixes come.

Each item lands on the ready line with its gates and CI green; the log below says when.

## Log

- 06:01Z: `main` (`8f1396f`) merged into the ready line, `401e201`: no conflict, and
  `git diff origin/main 401e201` is empty. Next: the working branch, then T2/SW1.
