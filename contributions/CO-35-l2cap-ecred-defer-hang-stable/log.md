# CO-35 — log

## 2026-10-23 — the hang (before the dossier)
Found in CO-02's and CO-10's full runs; swept on five kernels with `tmp/l2cap-hang/sweep-images.sh`
(STATUS, BT-10).

## 2026-10-28 — the fix found and confirmed on 7.2.13; dossier opened
In the walkthrough of every possible submission. `dc1ddc65f06df` alone does not fix it; a first
bisect was confounded by a second, newer hang (the SCI layout bug, fixed by `5874f8d03268`); the
second bisect, with that fix applied where needed, ends at `32d86e048d8ef`. 7.2.13 with it and its
helpers `608e0b7a675b2` passes the case and the whole l2cap-tester (111/111), kernel log clean.
Both commits reached mainline this week; neither carries `Cc: stable` or is queued. Details:
`experiments/results-2026-10-28.md`. 6.18.59 + the pair applies but does not build (lock
annotations 6.18 lacks), so only 7.2.y takes it as it is.
