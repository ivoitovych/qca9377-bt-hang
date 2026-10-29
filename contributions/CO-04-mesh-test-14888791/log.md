# CO-04 log

Append-only. Newest last.

## 2026-10-18 — found
While searching for a newer version of Jiale Yao's patch: Igor Putko's 14888791 (2026-10-14).
- Its `mesh_send()` hunk is identical to Hui Peng's 14831271, plus `hdev->lock` in three
  functions.
- 2026-10-15: Hillf Danton put it to syzbot, and syzbot replied "the reproducer did not
  trigger any issue".

Recorded in STATUS (the Tested-by row).

## 2026-10-20 — the diff read
Read from patchwork's API. It does not touch `mesh_send_sync()`'s `hci_add_adv_instance()`,
so I12 (CO-05) stays open. It takes `hdev->lock` in `mesh_next()`, which is the lock-order
question to test.

## 2026-10-21 — reviewer 1
The reviewer raised the same lock-order question; they made no run. They said the four mesh
patches "do not appear to conflict textually". That is wrong for 14888791 and 14831271
(`reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI5).

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4
- **All three:** do not endorse 14888791 unchanged, because of `cmd_sync_work_lock →
  hdev->lock` from the destroy callback.
- **Reviewer 4 adds two points,** both confirmed from the diff:
  - the lock is also taken in `mesh_send_start_complete()`'s error branch, before the
    `-ECANCELED` test;
  - `list_empty(&hdev->adv_instances)` in `mesh_send_done_sync()` stays outside the new lock.
- **Shared rule:** a Tested-by is ruled out if our device-removal lockdep case reports the
  inversion. The ordinary use-after-free reproducer passing is not enough.
- **Reviewer 4's `git apply` checks** (not re-run here): Hui Peng's patch and this one conflict
  in either order. Cen Zhang's 14880941, this one and Jiale Yao's apply mechanically in that
  order.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV4.

## 2026-10-21, worker W4 (QEMU only) — tested as posted; no Tested-by
Applied unchanged with `git am`. It introduces a lockdep circular-locking report (`hdev->lock`
taken in `mesh_send_start_complete()` / `mesh_next()` under `hci_cmd_sync_clear()`'s
`cmd_sync_work_lock`): 9 of 12 `-s power` boots, 0 on base. It fixes three failed-start cases.
The UAF it targets was not reproduced on base. Full account: `experiments/results-2026-10-21.md`.

## 2026-10-21 08:01 local — re-checked
`tmp/co05-check/recheck.sh power D-igor 1`: the inversion report, quoted in the results file;
`D-base 1`: clean.

## 2026-10-28 — freshness walkthrough
- **His patch:** still `new`, the same two replies (Hillf Danton's `#syz test`, syzbot's
  Tested-by of 10-15), no newer version, no maintainer reply (`python3 -I
  scripts/patchwork-state.py 14888791`; `scripts/patchwork-recent.py 2026-09-25 mesh`: no other
  mesh patch since but Cen Zhang's 14880941 and Jiale Yao's 14864878, both `new`).
- **The bug is open upstream:** syzbot's page (`tmp/walk-20261028/syz-mesh-uaf.html`) shows
  "KASAN: slab-use-after-free Read in mesh_send_sync", status "upstream: reported syz repro on
  2026/10/07", first crash 24 days ago, last 10 days ago, a retest of the reproducer on 10-17.
- **Our finding stands on today's tree:** the only mesh change in bluetooth-next since the tested
  base `27731ba09195` is none; the six commits since in `mgmt.c`/`hci_sync.c` (rfkill, accept list,
  resolving list, CIS, conn-flag bitmap, rx_work drain) do not touch the mesh functions
  (`git log -G mesh` since 10-01: only `8a8d51eeedeb`, already in the base).
- **Missing for a reply:** the reply's text (none drafted), one confirming `-s power` run on
  `47d4d9f67e92`, and the operator's decision.

## 2026-10-28, later — new direction: an independent fix (the operator's decision)
No reply on the 14888791 thread. Instead, our own fix for syzbot's "KASAN: slab-use-after-free
Read in mesh_send_sync" (still open upstream), sent as a separate patch to the Bluetooth
maintainers and the list. The technical reasons: the use-after-free is real and unfixed; the one
posted fix takes `hdev->lock` under `cmd_sync_work_lock`, inverting the existing lock order
(lockdep, 9 of 12 `-s power` boots, this dossier's results of 2026-10-21).
- **The patch:** written from the syzbot report and today's source, not from the earlier patch;
  `Fixes: b338d91703fa`; `Reported-by:` and, once shown to resolve it, `Closes:` for the syzbot
  report; credit only what it actually reuses (the `mesh_send()` failure-path change, if needed,
  first came from Hui Peng's 14831271).
- **Its notes below `---`:** a link to the earlier proposal and one or two technical sentences on
  the lock order. Nothing else.
- **Before it is sent:** a reproducer on an unpatched kernel (syzbot's program, or our mesh cases
  with a widened window); lockdep with the `-s power` cases, KCSAN on 4 CPUs, the full mesh-tester
  and mgmt-tester; the list bot's CI run here; syzbot's own test requested on the syzbot report's
  thread; outside reviews; then the operator's word. It must agree with CO-05, which locks the same
  function.
- **If anyone comments on our patch**, the points are answered technically on our thread.

## 2026-10-28 — syzbot's bug page read (read only)
- Saved in the worker's `tmp/mesh/syzbot/` (git-ignored): the page by id and by extid, the crash
  report, the console log, the kernel config, the 2026-10-17 retest's report and log, the
  2026-10-15 patch-test log. One crash (2026-10-03, upstream `3b7cab693ba2`,
  `ci-qemu-upstream-386`), a syz reproducer, no C reproducer; the 2026-10-17 retest on upstream
  `58161ead29e5` still reports it. The page asks for `Reported-by:
  syzbot+f20755f37da70df33a16@syzkaller.appspotmail.com` (`grep -n "Reported-by"
  tmp/mesh/syzbot/bug-extid.html` → `164: Reported-by: syzbot&#43;f20755f37da70df33a16@…`).
- **Root cause, from today's source:** the analysis is in
  `experiments/comparison-2026-10-29.md`, "The defect". In short: `HCI_MESH_SENDING` is cleared
  without `hdev->lock` in `mesh_send_start_complete()` and `mesh_send_done_sync()` before
  `mesh_next()` queues the list head, so a concurrent `mesh_send()` can queue the same
  `mgmt_mesh_tx` a second time; when the first start fails the entry is freed and the second
  start reads it. The read offset, 59 of 96 bytes, is `send->cnt`, the first field
  `mesh_send_sync()` reads.

## 2026-10-29 — the operator's decision on reproduction, and the fix written
- **Decision (operator, relayed 2026-10-29):** no use-after-free reproducer in any form, no use of
  syzbot's reproducer or crash input, no window-widening or fault patch on this fix's path, no
  `#syz test` (anything posted needs the operator's own word). The fix rests on the source
  analysis, the syzbot report's own text, lockdep assertions on the paths the fix locks, and the
  unmodified testers on base vs base+fix.
- **The fix:** "Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()", `caa2531f276f7` on
  bluetooth-next `1081a6ef8f1e0`; derived from our own V3 1/5 (`266dda8daee0`, 2026-10-04), not
  from 14888791. Comparison with V3 1/5, Baul Lee's v2 and the other pending patches:
  `experiments/comparison-2026-10-29.md`.
- **Decision: sent independently of CO-05** (not on top of it), because it is the stable-bound fix
  of a reported use-after-free, the two touch different functions, and they apply in either order
  to the same tree (`git diff --stat mesh/both-co05-co04-on-1081a6ef8f1e0
  mesh/co04-then-co05-on-1081a6ef8f1e0` → empty).
