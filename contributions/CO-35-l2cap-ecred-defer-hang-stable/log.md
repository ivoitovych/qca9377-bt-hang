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

### Fourth review round at `197a91a` (all six reviewers)

All six: code and trailers approved, no defect; reviewers 1 and 6 no findings (6 ran checkpatch:
only the known `[ Upstream commit ]` false positive and upstream's own warning). Done after it:
- backport notes wrapped to ≤ 75 columns (reviewers 2, 3); only upstream's `Fixes:` line is
  longer (76, never wrapped); `git diff --stat`: 5 files, note lines only; patches still apply.
- the results file's "Uncertain / side findings" items 1 and 2 updated: BT-14 queued upstream,
  post-hang cases now matched (reviewers 3, 4, 5); conclusion phrased as reviewer 2 proposed.
Noted, not changed: the raw QEMU logs and comparison scripts are local (`tmp/l2cap-hang/`), so
reviewers verified the records' consistency, not the raw verdicts (reviewers 2, 3, 4, 5).

### Fifth round, final go/no-go at `e2e0e00` (all six; patches only, blocking defects only)

All six: **GO for the six patches**, no blocking finding; the code diffs byte-identical to
`197a91a` (reviewers 2, 3, 5, 6 compared), trailers in order with the backporter's sign-off
last. The request mail was out of scope; reviewer 6: blocking for the *send* (not the patches),
it must add 7.3.y and 7.2.y before anything goes to stable@. Remaining: v7.3.y with and without
the pair; the request mails; their review; the operator's word.

## 2026-10-28 (20:30 to 21:40 UTC) — 7.3.y tested, older lines checked, send package written

Records: `experiments/results-7.3-and-older-2026-10-28.md` (runs, with commands and outputs),
`experiments/results-send-2026-10-28.md` (the package's checks), `send/README.md`. Scripts,
images and raw logs in the worker's `tmp/co35/` (git-ignored; `logs/SHA256SUMS`).
- **No newer tag** on any line (7.3.y has no release; 7.2.13, 6.18.59, 6.12.114, 6.6.160 still
  newest), the pair in no stable queue and on no line; so no rerun on 7.2.y or the backport
  bases. No 6.12.y release with `5bd0dec150f56` yet: BT-14 still limits 6.12's totals.
- **7.3.y:** the pair cherry-picks cleanly onto v7.3 and builds; the case alone hangs on plain
  v7.3 and passes with the pair (1.018 s). The whole l2cap-tester stalls on v7.3 in "L2CAP LE
  Client - SCI Fast Mode" with or without the pair (identical verdicts for the 41 cases before);
  with `5874f8d03268` applied to both sides the case hangs without the pair and passes with it,
  and the unfiltered l2cap-tester passes 111 of 111. All logs clean.
- **6.1.y, 5.15.y, 5.10.y** (no `ab4eedb790ca`; ECRED off by default before v6.2, so also run
  with `enable_ecred=1` set in the guest): as test-runner leaves them the case fails at once
  ("Can't set mode: Protocol not available"); with `enable_ecred=1` it never finishes on
  v6.1.190, v5.15.223 and v5.10.272, while the other Ext-Flowctl cases pass (positive control);
  the wrapper still shows the hang on the 6.6.160 control image. The pair does not apply there.
  The request names them as affected and not covered. Open: a fix for them.
- **What the hang is** (diagnostic build with `CONFIG_DETECT_HUNG_TASK`): on plain v7.3 the
  tester's task is "blocked for more than 20 seconds" holding its socket's lock from
  `l2cap_sock_recvmsg()` and waiting for the same lock in `l2cap_sock_teardown_cb()` (nested
  subclass, so lockdep is silent). By the source, `__l2cap_ecred_conn_rsp_defer()` runs under
  that lock and, when a sibling channel was closed, deletes the caller's own channel, whose
  teardown takes the socket lock again; that code is from v5.7. `32d86e048d8ef` releases the
  lock first. The mails now say this in one sentence each.
- **The case is now run alone.** A wrapper passes the exact case name (test-runner runs its
  arguments through `sh -c`, so `-s "<name with spaces>"` reached the tester as "L2CAP");
  plain v7.3 still hangs with it, so the earlier verdicts did not depend on the cases before.
  A full run filtered on "L2CAP" has 110 cases, not 111 ("Non-connected getpeername - Failure"
  has no "L2CAP" in its name); the 111-of-111 run on v7.3 is unfiltered, as `full-l2cap.sh` was.
- **Corrections:** (1) the first bisect's "second, SCI-caused hang on the same case" was a stall
  in "L2CAP LE Client - SCI Fast Mode", an earlier case that the split filter ran
  (`bisect-c4154fc34772.log`); the second bisect's hang steps stopped in the case itself, so its
  result stands. (2) The tester images have `CONFIG_DETECT_HUNG_TASK` off; "no hung-task report"
  (request-v1, STATUS BT-10) claimed a check that could not fire. The new mails say "no lockdep
  or KASAN report".
- **New issue (proposed BT-15):** v7.3 has the SCI feature `2f8784cfe8a9` without its fix
  `5874f8d03268` (mainline, `Fixes:` tag, not queued for 7.3): the l2cap-tester stalls in its SCI
  cases. The 7.3 full suites were run with `5874f8d03268` applied to both sides.
- **The pair's origin:** patches 2 and 7 of Pauli Virtanen's 16-patch series "Bluetooth: L2CAP:
  fix and annotate l2cap_conn::chan_l locking"; all 16 in mainline, none on a stable line, eight
  with `Fixes:`. The mails say the other patches are not needed for this case and were not
  tested here.
- **Send package:** `request-v2.eml` (option 2, 7.3.y and 7.2.y, full IDs, in order) and one
  option-3 series per older line with a 0/2 cover (`send/<line>/`), generated by `git
  format-patch --subject-prefix "PATCH <line>" --cover-letter --base` from the backports
  git-am'd onto their tags; code identical (same patch-ids), trees equal to the tested commits.
  Decision: covers, because they carry the shared facts once; decision: Cc the author, the two
  maintainers and linux-bluetooth, not linux-kernel or Dan Carpenter (`blamed_fixes` only).
  checkpatch: only the `[ Upstream commit ]` false positive and upstream's own warning;
  ci-local `--kernel`: `git am` PASS on each tag, the expected GitLint title length and
  VerifyFixes (6.12, 6.6) findings; mail-lint clean. Nothing sent.

## 2026-11-01 — review round: origin corrected, bases stale
- **The origin was wrong.** This log (2026-10-28) and the README said the self-deadlock path dates
  from v5.7 (`15f02b9105625`). v5.7's `__l2cap_ecred_conn_rsp_defer()` only collects the CIDs
  (`git show 15f02b9105625`). The `l2cap_chan_del()` on the caller's own channel comes from
  `9aa9d9473f15` ("Bluetooth: L2CAP: Fix responding with wrong PDU type", first in v6.3-rc4),
  backported as `c357e28b01c4c` (v6.1.22), `c35fd1b9b90a2` (v5.15.105) and `fce0e47e9ec5a`
  (v5.10.177). README, STATUS (BT-10) and issues.md corrected; the dated results file is left
  as written. The send mails never said v5.7.
- **The 2026-10-30 releases.** v7.3.1, v7.2.14, v6.18.60, v6.12.115 and v6.6.161 exist now; the
  mails name the previous tags. All three series and the upstream pair still apply to the new
  tags (`git apply --check`, offsets only; on v6.12.115 patch 1's hunk at the
  `l2cap_check_encryption()` site applies at 7680, offset 5; an outside reviewer's report that
  it fails there is wrong). Upstream `86b55991d3cd6` (patch 16 of the same upstream series) is
  now on all five lines; BT-14's `getsockopt` fix is released in v6.12.115 (`4b26b1d3a94cc`), so
  the 6.12 cover's "already queued" sentence and its 33/111 caveat are out of date. The hang
  case is not yet re-run on the new tags.
- **Not requested and not named:** `dc1ddc65f06d` (Pauli Virtanen, "take lock for l2cap_chan_del
  in l2cap_ecred_rsp_defer", in mainline, no `Fixes:`/`Cc: stable`).

## 2026-11-01 — re-tested on the new tags; refreshed drafts
QEMU/KVM, 4 vCPUs, BlueZ `doc/tester.config` + `CONFIG_DETECT_HUNG_TASK=y` (20 s); builds
09:00:50 to 09:48:34 UTC, runs 09:19:17 to 09:51:41 UTC. Case "L2CAP Ext-Flowctl Server - Accept 2
Close 1" alone (180 s limit):

| tag | base | with the series (7.x: the upstream pair) |
|---|---|---|
| v7.3.1 | hang | pass 1.119 s |
| v7.2.14 | hang | pass 1.068 s |
| v6.18.60 | hang | pass 1.126 s |
| v6.12.115 | hang | pass 1.078 s |
| v6.6.161 | hang | pass 1.402 s |

Every base hang has 5 to 7 hung-task reports: the socket lock held from `l2cap_sock_recvmsg`, its
`/1` subclass awaited in `l2cap_sock_teardown_cb`. Full l2cap-tester, patched against pooled base
verdicts (a full base run stops at the hang; one-word reruns fill in, 102 cases per tag): v7.2.14
111/111; v6.18.60 93/111 (18 PHY failures, ENOPROTOOPT); v6.12.115 79/111 and v6.6.161 79/111 (32
non-pass each: 26 PHY, 3 TX timestamping, 2 ethtool, 1 PIN timeout); v7.3.1 the pair alone stalls
in "SCI Fast Mode" as its base does, the pair + `5874f8d03268` 111/111. In every tag no case that
passes on base fails with the series. 6.12.115 went from 33 to 79 because `4b26b1d3a94cc` (BT-14)
is released there. v7.3.1 base + `5874f8d03268` still hangs in the case; pair + `dc1ddc65f06d`
passes it (1.025 s), so `dc1ddc65f06d` is not needed for the hang (tested on v7.3.1 only).

**Stable-size question** (an outside reviewer): no equivalent of the pair within 100 lines with
the same locking. The two helpers patch 2 needs plus the unchanged `l2cap_sock_defer()` are 118
changed lines (148 with context). An ECRED-only sketch (`send-20261101-draft/sketch-ecred-only-v7.3.1.diff`,
~82 changed, 102 with context) leaves the LE and BR/EDR defer branches without `conn->lock`, so
its locking differs from upstream; on v7.3.1 + `5874f8d03268` it passes the case and 111/111. Not
proposed: the upstream form stays, with one sentence in the covers on why the prerequisite is
needed.

**Drafts** in `send-20261101-draft/` (the 10-28 `send/` is kept): `request-v3.eml` (new bases,
the prerequisite sentence, `dc1ddc65f06d` named and why it is not requested, the SCI paragraph
reduced to one sentence), `request-sci-7.3.y.eml` (a separate option-2 request for `5874f8d03268`,
7.3.y only: its fixed commit `2f8784cfe8a9` is in v7.3.1, not in v7.2.14; not in queue-7.3 at
09:45 UTC), the three series regenerated onto the new tags (patch-ids equal to the originals;
offsets only), and the cover diffs. mail-lint clean. Not rerun on the new files: checkpatch and
ci-local. Raw logs (local): `/root/exp/agent-work/co35/refresh-20261101/` with SHA256SUMS. Not
sent.

## 2026-11-02 — 7.2.y has ended; an outside review's points
- kernel.org's release list of 2026-11-01 marks 7.2.15 as the last 7.2.y release. The request
  `request-v3.eml` still asks for 7.2.y: it is to be reworded to 7.3.y alone before any send.
- v7.4-rc1 is tagged (`git ls-remote` on the mainline tree, 2026-11-02: `bc71431221f5`). The two
  commits reached mainline in the 7.4 merge window; their presence in the tag is to be checked
  before the request (and before CO-22's ASUS request).
- From the same review, to do before sending: one source-level sentence on why `dc1ddc65f06d`
  (sibling-channel locking in `l2cap_ecred_rsp_defer`) is not needed for this backport, beyond the
  passing case; and a sentence in the request that the deadlock is older than `ab4eedb790ca` (the
  path dates from `9aa9d9473f15`, v6.3) and that the upstream fix resolves it there too, while the
  upstream `Fixes:` trailer stays unchanged.

## 2026-11-02 — the send package made final (`send-20261102/`; nothing sent)
- **Facts** (releases.json and git, 11-02): newest tags 7.3.1, 6.18.60, 6.12.115, 6.6.161 (the
  tested ones); 7.2.15 EOL. All of `608e0b7a675b2`, `32d86e048d8ef`, `5874f8d03268` and CO-22's
  `d54601f21faf`, `cfa67a1dbfd9` are ancestors of v7.4-rc1 (tag `bc71431221f5`, commit
  `6628e7d4c6b2`); none is in any stable queue (control stem found on every line) or released tag.
- **Mails corrected:** 7.2.y gone everywhere; request subject "Please backport 608e0b7a675b and
  32d86e048d8e to 7.3.y" (63 columns; the SCI request's subject shortened too); covers say "all
  other non-passes are pre-existing on the plain tag" (breakdown in `results.md`); one sentence on
  the size (`608e0b7a675b2` changes 78 lines, a 149-line diff, over the 100-line rule; requested
  whole as the conservative choice); one source sentence on `dc1ddc65f06d` (at v7.3.1
  `l2cap_ecred_rsp_defer()` calls `l2cap_chan_del()` on sibling channels without their
  `chan->lock` only in the refusal branch, separate from the socket-lock self-deadlock; the case
  passes with and without it); one neutral sentence that the path predates `ab4eedb790ca` (from
  `9aa9d9473f15`, v6.3). `Fixes:` trailers and Pauli Virtanen's patch bodies byte-identical to the
  drafts (`cmp`). Diffs against the 11-01 drafts in `send-20261102/diffs/`.
- **Patch-id note (corrects the review document, not this dossier):** this log's "same patch-ids"
  (lines 143, 204) and `results-send-2026-10-28.md` compare the mails with our own backport
  commits, and are right. Against upstream only 6.18.y's patch 2 is equal; the review document's
  wording "same as the upstream hunks" was wrong and is corrected there.
- **Tests on the final files** (QEMU/KVM, 4 vCPUs, tester.config + hung-task detection, the case
  alone, 180 s): v6.6.161, v6.12.115, v6.18.60, v7.3.1 plain hang (7 hung-task reports each),
  patched pass in 1.036 / 1.074 / 1.067 / 1.034 s; v7.3.1 + the pair + `5874f8d03268` also passes
  (1.040 s). Full l2cap-tester patched: 93/111 (6.18.60), 79/111 (6.12.115, 6.6.161), 111/111
  (7.3.1 with the SCI fix); 0 regressions against the 11-01 plain verdicts; no lockdep or KASAN.
- **Checks:** checkpatch: only the expected `[ Upstream commit ]` errors (6) and upstream's own
  syzkaller-link warning on each patch 1; mail-lint clean on both requests and three covers;
  ci-local `git am` passes; gitlint title length 82/82/81 and VerifyFixes on 6.12.y/6.6.y as on
  10-28 (both expected for stable backports).
- Raw logs, worktree-built bzImages and SHA256SUMS: `/root/exp/agent-work/co35-ready-20261102/`
  (local). Ready for the operator's word, the dry run, and his send.
