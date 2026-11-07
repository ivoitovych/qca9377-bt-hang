# The mesh-tester work — task briefs, results, reviews and gates

Everything in this directory, and the patches in [`patches/mesh-tester/`](../../patches/mesh-tester/),
was written on the branch `diag/mesh-tester-ci` between 2026-09-29 and 2026-10-08, while kernel
findings were kept off `main` until their patch was sent. The branch was kept separately;
its files were ported to `main` on 2026-10-09 as a new commit, under the same paths. So
banners such as "Kept separately until sent" describe that period, not the files' status now.

Where things stand is in [`docs/STATUS.md`](../STATUS.md) (rows `M-1`, `M-2`, `M-3` and the
mesh submission row) and in `BRIEF.md`. Reading order for the work itself:

1. [`TASK.md`](TASK.md) — why the list's CI bot fails `mesh-tester`;
   [`phase1-findings.md`](phase1-findings.md) — the diagnosis;
2. [`phase2-results.md`](phase2-results.md) … [`phase5-results.md`](phase5-results.md) — fixes and
   test records, phase by phase, with the briefs `PHASE3-TASK.md` … `PHASE5-TASK.md`;
3. the outside reviews: [`review-series-2026-10-02.md`](review-series-2026-10-02.md),
   [`review-series-v2-2026-10-03.md`](review-series-v2-2026-10-03.md),
   [`research-review-2026-10-05.md`](research-review-2026-10-05.md);
4. [`STATE-MACHINE.md`](STATE-MACHINE.md), [`gates-2026-10-05.md`](gates-2026-10-05.md),
   [`validation-2026-10-05.md`](validation-2026-10-05.md) — the design document and the research
   gates that decided the order of the separate contributions;
5. the BlueZ `shared/mgmt` leak (sent and applied 2026-10-08): `REVIEW-REQUEST-bluez-shared-mgmt-leak-*`,
   `review-response-*`, the logs' `SHA256SUMS`.

`tools-phase5/` keeps the build and run scripts of the QEMU harness as they were used; they ran
on the development host, never in this repository's suite.

Also here, not in the reading order above (listed 2026-10-28):
- the review briefs: `REVIEW-TASK.md`, `REVIEW-TASK-SERIES.md`, `REVIEW-TASK-SERIES-V2.md`,
  `RESEARCH-AND-REVIEW-TASK-2026-10-05.md`;
- the retest of another author's patch (Hui Peng's 14831271): `retest-review-2026-10-06.md`, `-2-`
  and `-3-` (the report itself is `retest/mesh-tx-leak/REPORT.md`);
- `validation-extra-paths-2026-10-05.md`, beside `validation-2026-10-05.md`;
- M-2's arithmetic: `duration-overflow-note.md`, `-v2.md`, `-v3.md` (the latest is v3; STATUS's
  M-2 row and CO-12 carry it on);
- the logs' checksums: `logs-phase5-SHA256SUMS`, `logs-val2-SHA256SUMS`,
  `logs-bluez-2026-10-07-SHA256SUMS`, `logs-bluez-d84171e6c-SHA256SUMS`, and the clang analyzer
  output of 2026-10-08 (`logs-clang-analyze-2026-10-08/`).

One document of that period is not here yet: the comparison of the power-off fix with another
author's posted patch, which waits until a reply on his thread is decided.
