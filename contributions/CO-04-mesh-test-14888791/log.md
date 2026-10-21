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
