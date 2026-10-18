Snapshot of the open trial E3 #1, taken 20261018T145830Z by scripts/trial-snapshot.sh
(checkout 4522ae3, boot 17cfdfc4377b4667a9fc8bf94c177fda). The trial was left open.

It covers the trial from its start (2026-10-13 20:29:17 +0200) to the
snapshot. row.tsv is the row main's closer computes at that moment (passive,
600 s budget); the real close at shutdown writes its own row to
evidence/trials/results.tsv if it gets that far.

If the shutdown close writes no row: this row is the trial's record up to the
snapshot, and the rest of the boot is in the journal of boot 17cfdfc4377b4667a9fc8bf94c177fda
(scripts/boot-bt-summary.sh 17cfdfc4377b4667a9fc8bf94c177fda for its SCO ledger, timeouts and
error lines). Add a row to results.tsv only by a reviewed commit that says
where it came from; never edit this snapshot.

Read-only on the machine: nothing was sent to the controller, no unit was
touched, nothing was written to the journal.
