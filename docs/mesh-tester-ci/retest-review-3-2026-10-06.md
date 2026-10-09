# Review of the retest at 3c17c36 (round 3)

Reviewed 2026-10-06: five commits on top of `a3858e6`. Read in full: REPORT.md, both
READMEs' changes, every changed or new script (`audit-logs.sh`, `kmemleak-after-exit.sh`,
`run-kmemleak-reps.sh`, `run-busy-drain-reps.sh`, `summarize.py`, `tabulate-reps.py`),
`results/summary-reps.md`.

## Mechanical checks

`tmp/mesh-tester-ci/retest-verify.sh <kit> tmp/mesh-tester-ci/retest-verify-out-3c17c36`
(tabulate step updated for the renamed `summary-reps.md` and its four builds):

* `audit-logs.sh logs`: identical to `results/audit.txt`, `AUDIT OK`, exit 0, with the
  stricter checks (tester summary complete and consistent with exit status, end-of-scenario
  line, after-exit reproducer status 0, kmemleak rounds 1–5 without gaps).
* `summary-main.md`, `summary-kmemleak.md`, `summary-reps.md`: regenerated identically.
* 159 logs: the previous 139 plus `reps-control/` 10 and `reps-patched/` 10 (busy-drain).
* errnos: `-100` ×132 (was 72; +60 = 20 busy-drain runs × 3 failures), `-12` ×53, `-19` ×32.
* Privacy: unchanged; the same three BlueZ test addresses in the two mgmt-tester logs, only
  the author's address otherwise.

## Code claims checked

* O2/O3 scheduler mechanism at `036d4119079a`: `mesh_send_done_sync()` clears
  `HCI_MESH_SENDING` and completes `mgmt_mesh_next(hdev, NULL)`, the first pending entry of
  any socket (mgmt.c:1096-1109); it is queued with `mesh_next` as its completion
  (mgmt.c:1137); `mesh_next()` queues the new first pending entry to `mesh_send_sync()`
  (mgmt.c:1113-1127). Neither step looks at whether that entry's Mesh Send failed. REPORT's
  two-step description is exact.

## Round 2 points, status

1. O1 general sentence: fixed, now "the reference taken for the failed request is never
   dropped".
2. "independent": fixed, "A separate retest".
3. `run-kmemleak-reps.sh` failure aggregation: fixed, as are `kmemleak-after-exit.sh` and the
   new busy-drain runner.
4. O3 on one run: fixed, busy-drain repeated 5× per advertising type on both kernels; every
   observation 5/5 on control, the failure-specific ones 0/5 on patched (summary-reps.md).

Also fixed on the author's own initiative: the tester parser compared 475 of 503 mgmt-tester
cases; it now compares all 503 and flags incomplete summaries (no change in result).

## Verdict

No remaining problems. Ready to bring into this repository as a squashed copy of
`bluetooth/mesh-tx-leak/` at `3c17c36`, with the three BlueZ test addresses allow-listed
exactly in the publish scan.
