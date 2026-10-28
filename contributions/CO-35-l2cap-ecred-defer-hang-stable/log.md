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

## 2026-10-28 — six outside reviews of `24d76cd` (relayed by the operator; not consent)
All six: the request is valid (option 2, two commits in order). To do before sending:
1. **A plain 7.2.13 control** (four reviewers): the draft said the case hangs on 7.2.13, but only
   7.2.12 had been run unpatched. **Done 2026-10-28:** `try-picks.sh … 7.2.13-plain v7.2.13`
   (no commits): `make rc=0`, then "bzImage-bt10-7.2.13-plain: HANG (limit 180 s)". The sentence
   stands as written.
2. **7.3.y** (reviewer 5): v7.3 (2026-10-18) lacks both commits, and `stable/linux-7.3.y` exists
   (`git ls-remote`, 2026-10-28). Test v7.3.y with and without the pair, and request 7.3.y and 7.2.y
   together: a fix must not skip a newer stable line.
3. **Qualify the bisect** (reviewers 3, 4): "After excluding an unrelated, newer hang on the same
   case, a second bisect identified 32d86e048d8e" — or drop that sentence.
4. Full hashes in the mail (reviewer 5); send promptly (reviewer 6: 7.2.y has few releases left);
   6.18.y (LTS) is the lasting value: the backport series being prepared.
