# Phase 5 — revise the series after the v2 review of 2026-10-03

**Private until sent.** The review is `review-series-v2-2026-10-03.md` (same directory). Its
verdict: *do not send this revision yet* — the successful-path ownership fix, the common
tear-down helper and the owner matching stand; five findings must be closed. Each was checked
here against the source on 2026-10-03 and holds.

## Verified findings

1. **Initial enqueue failure breaks the ownership invariant (blocker).** `mesh_send()`'s error
   cleanup is inverted (`mgmt.c:2610-2613`: `if (mesh_tx) { if (sending) mgmt_mesh_remove() }`
   — the only way to reach it with a live `mesh_tx` is a failed `hci_cmd_sync_queue()`, which
   happens only when `sending` is false). The rejected request stays on `mesh_pending`, the
   flag stays clear, and under v2 `mesh_next()` starts it after the next successful request's
   completion — a request userspace was told failed is transmitted. Pre-existing cleanup bug,
   new consequence under v2. **A public patch by another author already proposes the
   one-line cleanup** ("Bluetooth: MGMT: fix mesh_tx leak on hci_cmd_sync_queue() failure",
   2026-09-19, lkml; `Fixes: b338d91703fa`; compile-tested only, not in `bluetooth-next`
   `036d4119079a` nor in the `bluetooth` tree as fetched 2026-10-03). The series must depend
   on that fix with its provenance — **never re-author it**: name it as a prerequisite in the
   cover and in 1/3's stable tag if it lands first, or, if it has not landed by send time,
   say in the cover that the series assumes it and why (the maintainers decide the order).
2. **The done deadline is not the Count contract.** `mesh_send_start_complete()` arms the done
   work at `cnt × 25 ms` (`mgmt.c:2369`), while the instance is added with the adapter's
   advertising interval (default `0x0800` = 1280 ms) and a duration of `cnt × interval`;
   extended enable leaves `max_ext_adv_evts` zero. Before 2/3 the instance outlived the
   deadline by 1000 s, so the mismatch was invisible; with an effective tear-down, Count=3 may
   air one event. Pre-existing; **exposed** by this series. Decide, with evidence: fix the
   deadline (`cnt × interval`, or set `max_ext_adv_evts = cnt` where extended) as a
   prerequisite, or document the limitation. Until decided, the cover may not say the packet
   "ends after its requested count".
3. **The active-cancel case can pass without its scenario.** Once `mesh_tx_cancel_sent` is set
   the test accepts B starting before the cancel took effect; A may complete naturally first;
   cancelling an absent handle succeeds. Same observable sequence as natural A-then-B.
4. **The power-off argument was wrong (ours).** `__hci_cmd_sync_sk()` / `hci_req_sync_run()`
   have no HCI_UP guard (`hci_sync.c:115-217`); a start accepted before power-off runs after
   it and reaches whatever the driver does with a command on a closed device, or the 2 s
   command timeout — not a prompt `-ENETDOWN`. The behaviour is **not established**.
5. **The duration note misses remainder 8.** `(timeout × 1000) mod 65536` is a multiple of 8;
   remainders 0 and 8 both encode `Duration = 0`, so timeout ≡ 0 **or 6357 (mod 8192)** gives
   no finite controller duration — 15 positive values, not 7. The table rows are right.
6. **Record errors**: phase4-results claimed the BlueZ patch carries `Signed-off-by` (it must
   not and does not — corrected 10-03); the "successful dequeue of a queued start" was not
   exercised by the named cancel-queued case (B's start is not yet queued when cancelled);
   "microseconds" in the cover is a scale, not a measurement; the valgrind unpatched baseline
   used the earlier tester.

## The work

**A. Dependency.** Check `bluetooth-next`, `bluetooth` and patchwork (`scripts/patchwork-checks.sh`,
lore) for the 2026-09-19 leak fix. If applied: rebase, add it to the stable prerequisite line
of 1/3, re-run every gate. If not: the cover states the dependency and its author's thread; 1/3's
comment at the flag states the invariant *given that cleanup*; do not include the diff. Either
way, **a guest-kernel test of the failing-allocation case**: fault-inject the first
`hci_cmd_sync_queue()` (a `btdev`/fault-injection lever, or `CONFIG_FAULT_INJECTION` on the
allocation), then assert the rejected handle is absent from Read Mesh Features, never started,
never completed, and the next accepted request progresses. Add `lockdep_assert_held(&hdev->lock)`
in `mesh_next()`.

**B. Count/deadline.** Receiver-enabled extended-emulator test (second `btdev`, duplicate
filtering off, distinct PDUs): Count=1 and Count=3 at the default and at a configured interval;
record enable/disable timestamps and received events. Then decide: prerequisite fix or
documented limitation. Cover and results carry the review's interim sentence until then:
*"The tests verify command ordering, ownership and teardown at the existing Count × 25 ms host
deadline. They do not establish the requested number of advertising events or receiver
delivery."*

**C. Tester.** Active cancel: hold A's initial enable response, acknowledge B, enqueue
Cancel(A), prove the enqueue (trace or a validated dispatch barrier that cannot deadlock behind
the serialized client's outstanding reply), release the hold; assert A cancelled, B started once,
one completion per handle. Add the **queued-start dequeue** case: hold A's tear-down, Cancel(B)
while B is pending, release; prove `mesh_next()` queued B's start behind the cancel work and the
dequeue succeeded; a later request verifies hand-over. Say in the results that the *new
lifecycle operations* check returns, not every send in the file.

**D. Power transitions and unregister.** Tests: power-off with a queued start, with an active
owner, with the tear-down held; unregister with a backlog. Require bounded completion and a
working Send after reopen. Replace every statement of the `-ENETDOWN` argument (BRIEF, results,
the review task) with the review's wording. If a test shows a stale flag after reopen, that is a
new finding: fix or scope it explicitly.

**E. Lifetime (scoped, not fixed here).** Socket close during queued/running work predates the
series (`mgmt_cleanup()` without `hdev->lock`). Run a differential close-race test (K vs V)
under KASAN + lockdep, KCSAN if available, and state the non-regression result; do not add an
`hdev->lock` inside `mgmt_cleanup()`'s `hci_dev_list_lock` section. Note the two August public
locking proposals as context, not as drop-in prerequisites.

**F. Messages.** 2/3's "reused by the next one" comment → the review's replacement (*"Account
for the request even if teardown fails. Recovery of a residual advertising instance is not
handled here."*). Cover: replace "With only the tear-down applied…" with the review's sentence;
drop "microseconds"; keep "no stable kernel was built or run"; add the scope sentence of B.
Duration note: the remainder-8 row and paragraph.

**G. Rerun every gate** on the final dependency sequence (mesh-tester old + new on BREDRLE and
BREDRLE50, KVM and TCG+valgrind, ASAN; mgmt-tester; repeats; checkpatch `--strict --codespell`;
W=1; sparse; cumulative stable apply; recipients). **Keep the raw logs in the branch this time**
(`docs/mesh-tester-ci/logs/phase5/`, or `cache/` with sha256 in the results) — the reviewer could
not inspect phase 4's runs. Record in `phase5-results.md` after every step.

## Constraints (unchanged)

qemu only; never touch the host's Bluetooth or kernel; writes only under `cache/` and
`tmp/mesh-tester-ci/`; post nothing; another author's
patch is referenced by subject, date and thread, never copied into this tree; author of the
project's patches: Iaroslav Voitovych <yaroslav.voytovych@gmail.com>.
