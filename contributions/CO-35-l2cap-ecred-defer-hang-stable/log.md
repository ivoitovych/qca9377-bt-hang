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

## 2026-10-28 — backports for 6.18.y, 6.12.y and 6.6.y

`backports/<line>/0001-…`, `0002-…` (format-patch); commands and verdicts in
`experiments/results-backports-2026-10-28.md`; scripts in `tmp/l2cap-hang/`.
- Patch 1 on all three: only the three lock annotations those trees lack are dropped
  (`__must_not_hold`, the `__cond_acquires` half on `l2cap_chan_lock_conn()`,
  `__context_unsafe`); code unchanged; `[ backport: … ]` note.
- Patch 2: 6.18 unchanged (offsets); 6.12 and 6.6 lack the `MSG_ERRQUEUE` block in
  `l2cap_sock_recvmsg()`, so those three lines are absent; `l2cap_sock_defer()` and its call as
  upstream.
- "L2CAP Ext-Flowctl Server - Accept 2 Close 1": base HANG, backport Passed on v6.18.59, v6.12.114
  and v6.6.160. Full l2cap-tester with the backport: 93/111, 33/111, 79/111; by case name, no case
  that passes on the base fails with the backport; the shared failures are features the trees lack
  (`BT_PHY` everywhere, `SO_TIMESTAMPING` on 6.6; the PHY sets were checked on the base with a
  PHY-only filter: 18, 28, 26). Report scans clean.
- 6.12's 78 failures are a separate stable defect: BT-14 (`docs/issues.md`), L2CAP `getsockopt`
  returns EOPNOTSUPP on 6.12.114.
- Caveat: `tmp/l2cap-hang/run-one.sh` passes the case name unquoted, so it filtered on "L2CAP"
  (whole suite to the hang). The verdicts stand; earlier single-case runs were full runs.
- Still to do before sending: v7.3.y with and without the pair; then the request (7.3.y, 7.2.y,
  and these backports).

### Outside review of the backports at `315c588` (reviewers 1, 2, 3, 5, 6; 4 unavailable)

All five approve the code: the only differences from upstream are the three annotations and
the three `MSG_ERRQUEUE` lines (reviewers 3, 5, 6 diffed every patch; reviewer 3 matched the
preimage blob hashes with the stable tags). Actions:
- **Backporter sign-off missing** (reviewers 2, 3, 5, 6; blocking): added to all six, with the
  `[ backport: ]` note moved below the upstream sign-offs (`git diff`: trailer lines only). By
  sending, the operator certifies the DCO for them, as on every patch sent so far.
- **Summary too broad** (reviewer 5): `experiments/results-backports-2026-10-28.md` now says
  "no regression among the compared cases" and names what was not compared.
- **Packaging** (reviewers 3, 6): option 2 for 7.3.y and 7.2.y (one mail), then each option-3
  series as its own mail, `[PATCH 6.18.y 1/2]` etc., each naming its tested base and its
  deviations; the 6.12 series states the BT-14 limit of its suite totals. Optional: a sparse run
  (reviewer 2).
- **BT-14 is known upstream** (reviewer 6; verified): patchwork 14907537, queued for 6.12 by
  Sasha Levin on 2026-10-23. Nothing to send.
- **7.3.y** (reviewer 6: released 2026-10-18, lacks both): test with and without the pair.
- Reviewer 4 (later, at `315c588`): applied all six with fuzz disabled on the three tags,
  clean; code approved; the same two points (sign-off, summary; both done in `ab6ba29`); and
  suggested matched base controls for the post-hang failures with one-word filters that avoid
  the hang (`ATT`, `Nval`, `Ethtool`): done, `tmp/l2cap-hang/post-hang-controls.sh`. Every
  case failing with the backport now fails on the plain base too, by name: 18/18 (6.18), 78/78
  (6.12), 32/32 (6.6), equal to the tester's own totals (`tmp/l2cap-hang/coverage-check.sh`;
  results file, "Matched controls for the post-hang failures"). No regression.
