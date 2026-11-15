# Checks of the five answers to the 2026-11-15 submitted-contributions status report

The answers are stored verbatim as `2026-11-15T0115Z-submitted-status-review-reviewer-{1,2,3,6,7}-verbatim.md`. They answer
`2026-11-15T0115Z-submitted-contributions-status.md` as of `48c147a`. Each answer is an opinion,
not the truth: every checkable claim was checked against the source, the records or live upstream
state on 2026-11-15, 01:45–02:45 UTC. Verdicts:
- **right**: the reviewer is right, and the report is corrected;
- **partly**: right in part;
- **wrong**: the claim does not hold, and the report stands;
- **open**: not settled yet; the work is assigned.

## Factual claims

| # | Claim (reviewers) | Verdict | What was checked |
|---|---|---|---|
| 1 | Patch 1 was exercised on the laptop, so "not exercised on the laptop" is false (R3, R7). R7: there is no unpatched hardware control. | **right** | `contributions/CO-02-…/experiments/results-2026-10-26-hw-connect-twice.md`, 2026-10-26 05:40–05:43: 3 of 3 second connects got `EBUSY`, the Shure call's link was kept, and its voice data had no gap (`EX-075`–`EX-077`). STATUS's U7 row records it too. The report took an older sentence of the same row ("Patch 1's case … not exercised on hardware"), written before that test. The failure itself was shown only in the emulator ("Connect Twice" fails on every unpatched kernel). |
| 2 | The lock-cycle analysis cites `add_device_complete()` wrongly: it takes `hdev->lock` only when `!err` (R7) | **right** | `mgmt.c:7856` at `da3cc02587c6`: `if (!err) { … hci_dev_lock(hdev);`. `hci_cmd_sync_clear()` (`hci_sync.c:684–687`) cancels entries with `-ECANCELED`, so this callback adds no edge. |
| 3 | A lock cycle through `cancel_delayed_work_sync()` under `hdev->lock` remains possible and is unresolved; "it already exists in `hci_conn_del()`" does not make a second wait safe (R2, R7) | **right, open** | The cycle's third edge still exists through `add_ext_adv_params_complete()`, which takes `hdev->lock` unconditionally (`mgmt.c:9259`), including on `-ECANCELED` under `cmd_sync_work_lock`. Reachability is not settled. Assigned to the SCO lane: corrected analysis, a lockdep-targeted QEMU test, and a non-sleeping alternative for 2/2 if needed. Until then 2/2 is not ready to send. |
| 4 | v2 1/2 keeps Wentao Liang's bug; the overlap is more than textual (R2, R6) | **right** | v2 1/2's `else` branch still calls `hci_conn_drop(sco)` when `hci_conn_link()` fails for a new connection, whose only hold comes from the link (`hci_conn.c:1870–1882`). So v2 keeps his bug: it neither fixes nor worsens it. 2/2 adds no path on that branch. A variant rebased on his patch, and a `git apply -3`, are assigned to the SCO lane. |
| 5 | The maintainer pointed an SCO author to Sashiko on 10-07/08, so the practice is not new since 11-11 (R7) | **right** | lore, `<CABBYNZK9Oy2iL5PosxRy1KPup0PgYDfPUxeHemjYjKyAUu4+=Q@mail.gmail.com>` (2026-10-08, quoting his 10-07 mail "Sashiko flagged quite a few problems" on Hitalo Souza's SCO abort series), fetched with `scripts/lore-git-message.sh`. The report's "all from 11-11 on" is an artefact: the local lore clone is shallow, with history boundaries at 11-11, 10-22, 09-15 and 07-23. |
| 6 | Mirror PR #1009 is still open (R6) | **wrong** | `gh api repos/bluez/bluetooth-next/pulls/1009`: `closed`, `closed_at 2026-11-11T23:58:09Z`. R7 also saw it closed. |
| 7 | The mismatch patch "comes from nowhere" (R6). It is not applicable to the untouched base (R7). | **partly / right** | It comes from the 11-02 review round: decision D2, `patch/mismatch-20261102/`, 315 QEMU runs on 11-02. Lane 7 added the incoming-link cases on 11-14. The report did not say so. R7 is right: its file applies only on top of 1/2 + 2/2 (its hunk contains 2/2's check). A standalone version is assigned. |
| 8 | Layout (b) already folds 2 and 3; it does not repeat v1's main mistake (R7, R6) | **right** | `mails/b-three/kernel/`: 1/3 hold, 2/3 folded fix, 3/3 mismatch. Its drawback is that it adds a second defect to the series. |
| 9 | Sashiko asked "fold, or make sure they go to stable together"; "one patch" is our conclusion. Name `sashiko-nipa` when meaning the instance maintainers see (R3). | **right** | STATUS, the CO-02 row (10-29 review): "fold 3 into 2 or to make sure the two go to stable together". The public sashiko.dev instance raised a different High, on patch 1, that predates the series. |
| 10 | The CI closure is not a substantive blocker for the kernel series, since v2 is needed anyway (R3) | **right** | v2 is needed for content (the fold), whatever the sweep did. For the BlueZ test, staleness is the real reason: its notes said a rebase would be owed if the tester series landed first. |
| 11 | Seven items mix kinds; the counts six, four and seven disagree; "57 days" against a send 40 days ago; "nobody from the maintainer side" next to Zijun Hu's reply (R6, R7, R2) | **right** | 57 days is the age of Hui Peng's patch (09-19); our Tested-by is from 10-06 (40 days). Zijun Hu is a Qualcomm engineer, not a maintainer of the tree; the wording blurred that. The report is regrouped into: waiting for us, waiting for upstream, watching, done. |
| 12 | "Not taking any mesh fixes" against two accepted (R3, R6, R7) | **right** | The chat summary said it, and the report's row 4 implied it. Two were accepted since 09-01 (Lee Jones v3, Pauli Virtanen); six by other authors are pending. |
| 13 | The statistics, the mood of 11-04, and "reviewer time only" are observations, not causes (R2, R3, R7) | **right** | Reworded. The 22 % / 15 % snapshot mixes revisions and submission ages. The 11-04 episode is evidence that a large batch creates review load, not that ours would be equivalent. |
| 14 | If the broken apply script produced earlier results, they are suspect; add a negative control (R6) | **checked: none** | The script was written on 11-15 for this report; the 11-14 checks used `scripts/pre-send-check.sh`, the package builds and the lanes' own harnesses. Negative control by construction: v2 2/2, whose context contains 1/2's lines, FAILS on the bare base with the fixed script and applied in the broken one. |
| 15 | Table rows are split across physical lines (R2) | **wrong** | Every row of the three tables is one line ending in `|` (`grep` on the file); likely a renderer wrapping long rows. |
| 16 | Patch 2 must not be backported alone; the cover should say so (R2) | **right, open** | Assigned to the SCO lane: the note in the cover and in 2/2, with the trailer form used in practice. |
| 17 | Apply `abort-reason-readonce.diff` or justify the plain read (R2) | **open** | Assigned to the SCO lane, as a variant, with KCSAN if practical. |
| 18 | Hitalo Souza's SCO abort series is next to CO-02 (found while checking 5; no reviewer raised it) | **checked** | v3 (14875449–14875454, 2026-10-08) is `new`, 38 days after the maintainer's engagement. 2/6 touches `hci_enhanced_setup_sync()` and `hci_sco_setup()`; v2 1/2 and 2/2 apply on top of it (`apply-alone.sh`). It also shows silence is the default even for a series a maintainer engaged with. |

## Strategy points

| # | Point (reviewers) | Assessment |
|---|---|---|
| A | Resolve the lock question before resending CO-02 (R2, R7). R1: do not delay indefinitely. | Agreed: CO-02 v2 waits for item 3, which is assigned now, not open-ended. |
| B | "One kernel submission at a time" is too strict; keep one complex series under revision, and let small independent tested patches through (R2, R7) | Agreed. Proposed order below. |
| C | Say which goes first (R6) | First CO-44, then CO-38 a week later; CO-02 v2 when item 3 is settled; then the mismatch patch. CO-25's reply is independent of all of these. |
| D | CO-25: send the reply (R2); the operator's decision (R1, R7) | Recommendation: send v4 as drafted, after the operator reads it. It is short and technical; the record (the device ID in btusb's ROME table, the rampatch and NVM loaded, the version line) is in it. |
| E | CO-04's open syzbot bug deserves attention; do not hold it only because other mesh patches wait (R2) | Partly agreed. CO-04 is our own standalone fix (the route decided 10-28) and can go in the paced order after CO-38. The other mesh packages (CO-05 + CO-26, CO-14) stay held. |
| F | Name Wentao Liang's patch in the v2 cover (R6, R2) | Proposed: one neutral sentence below `---` saying that it touches the same error branch and which way the rebase goes. Its attribution stays his. |
| G | The diagnosis is packaging and dependency boundaries, not weak evidence (R3, R7) | Agreed; the report's section is rewritten. |

## D1 and D2, restated (R6 asked for the options and a recommendation)

- **D1, when to post CO-02's next version, and its label.**
  - Label: v2, as checked.
  - Options for timing: now; or after the lock question (item 3).
  - Recommendation: after item 3, in layout (a).
- **D2, the mismatch patch: its error code, and whether to send it yet.**
  - Error code options: `-EBUSY` for a link in use and `-ECONNABORTED` for a closing one (R2 and R6 of 11-02); or a single code.
  - Timing options: with v2; or later on its own.
  - Recommendation: the split codes, sent later as its own patch against the base, after v2 has a review.

## Results of the open items (2026-11-15, later; `contributions/CO-02-…/review-fixes-20261115/`, checked on copy)

- **3, the lock cycle: reachable.** Reviewers 2 and 7 were right.
  - With debug-only delays standing in for the scheduling windows, the v2 kernel (1/2 + sleeping
    2/2) hangs 3 of 3. The trace ends inside `cmd_sync_work_lock` while
    `add_ext_adv_params_complete()` waits for `hdev->lock`.
  - Base and a non-sleeping alternative 2/2 pass 3 of 3.
  - "Not new" is withdrawn: on the base kernel nothing waits for a running `disc_work` under
    `hdev->lock`.
  - The alternative refuses when the worker is running instead of waiting. It gives sco-tester
    35/2/7 in each of 3 runs, mgmt 526/526 and iso 213/213. It is the new candidate.
  - The sleeping 2/2 is not to be sent.
- **4, Wentao Liang's patch:**
  - v2 keeps his bug and neither fixes nor worsens it (read from the code).
  - `git apply -3` conflicts in every order tried.
  - A rebased variant builds and gives the same results: sco 35/2 in each of 3 runs, mgmt
    526/526, iso 213/213.
- **7, the standalone mismatch patch:** made against the bare base. Its two cases pass 3 of 3.
- **16, the stable note:** written into the covers and 2/2. The trailer form is proposed in the
  package README; it is the operator's call.
- **17, `READ_ONCE()`:** annotation hygiene, not a functional need. KCSAN (3 runs each) found
  nothing on `abort_reason`, and it does not settle the question.
