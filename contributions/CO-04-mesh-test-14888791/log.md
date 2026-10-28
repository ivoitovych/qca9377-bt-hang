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
