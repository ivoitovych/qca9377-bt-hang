# The mesh-tester work — task briefs, results, reviews and gates

Everything in this directory, and the patches in [`patches/mesh-tester/`](../../patches/mesh-tester/),
was written on the branch `diag/mesh-tester-ci` between 2026-09-29 and 2026-10-08, while kernel
findings were kept off `main` until their patch was sent. The branch lived in the project's
private repository; its files were ported to `main` on 2026-10-09 as a new commit, under the
same paths. So banners such as "Private until sent" and links into the private repository
describe that period, not the files' status now.

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

One document of that period is not here yet: the comparison of the power-off fix with another
author's posted patch, which waits until a reply on his thread is decided.
