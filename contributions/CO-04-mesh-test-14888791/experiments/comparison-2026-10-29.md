# CO-04 — the independent fix compared with our V3 1/5 and with other pending patches, 2026-10-29

By reading the code (no run). The fix is "Bluetooth: MGMT: Fix use-after-free in mesh_send_sync()",
commit `caa2531f276f7` (tested; final message `6d7ae083f6165`) on bluetooth-next `1081a6ef8f1e0`
(`../patch/`). Applicability by `git apply --check` of the posted mboxes on four bases
(`tmp/mesh/apply-matrix.sh`; the worker's progress file has its output).

## The defect, from the source of `1081a6ef8f1e0` [quoted lines; the sequence is inferred]

- `mesh_send()` (`mgmt.c:2535`–`2554`, under `hdev->lock`): `sending = hci_dev_test_flag(hdev,
  HCI_MESH_SENDING)`; if clear, `hci_cmd_sync_queue(hdev, mesh_send_sync, mesh_tx,
  mesh_send_start_complete)` for the entry it has just added, then `hci_dev_set_flag(...)`.
- `mesh_send_start_complete()` (`mgmt.c:2316`–`2321`, worker, no `hdev->lock`), on a failed start:
  `hci_dev_clear_flag(hdev, HCI_MESH_SENDING)`, `mesh_send_complete(hdev, mesh_tx, false)` (frees
  the entry), then `mesh_next(hdev, NULL, 0)` unless `-ECANCELED`.
- `mesh_send_done_sync()` (`mgmt.c:1102`–`1108`, worker, no `hdev->lock`): clears the flag, may send
  an HCI command, completes the head; its destroy callback `mesh_next()` follows.
- `mesh_next()` (`mgmt.c:1115`–`1129`): queues `mesh_send_sync()` for `mgmt_mesh_next(hdev, NULL)`,
  the head of `hdev->mesh_pending`, with no test whether that entry already has a start queued,
  and sets the flag.
- `hci_cmd_sync_queue()` (`hci_sync.c:753`) does not look for an existing entry
  (`hci_cmd_sync_queue_once()` does; not used here).

So a `mesh_send()` that takes `hdev->lock` between the worker's flag clear and `mesh_next()` queues a
start for its new entry; if that entry is the head, `mesh_next()` queues a second start for the
same pointer. If the first start fails, its `mesh_send_start_complete()` frees the entry and the
second start reads it. syzbot's report matches this: allocated in `mesh_send()` →
`mgmt_mesh_add()`, freed in `mesh_send_start_complete()` → `mesh_send_complete()` on the
`hci_cmd_sync_work` worker, read by `mesh_send_sync()` on the same worker; the read is 59 bytes
into the 96-byte object, which on this layout (`mgmt_util.h:20`–`28`: list 0–15, index 16, param_len
24, sk 32, handle 40, instance 41, param from 42; `mgmt_cp_mesh_send`: addr 6, type 1, instant 8,
delay 2, cnt 1) is `param + 17` = `send->cnt`, the first field `mesh_send_sync()` reads
(`duration = send->cnt * ...`). Its retest of 2026-10-17 on upstream `58161ead29e5` shows the start
failing as `Opcode 0x2008 failed: -110` just before the report.

`-ECANCELED` reaches `mesh_send_start_complete()` only from `_hci_cmd_sync_cancel_entry()`
(`hci_sync.c:652`), whose callers (`hci_cmd_sync_clear()`, `hci_cmd_sync_cancel_entry()`,
`hci_cmd_sync_dequeue()`, the create-connection cancels at 7520/7548) all hold `cmd_sync_work_lock`.
The only in-flight `hci_cmd_sync_cancel(hdev, ECANCELED)` calls (7510, 7541, 7568) are guarded to the
connection's own create command, so `mesh_send_sync()` does not return `-ECANCELED` itself
[inferred from those guards].

## The fix

- `mesh_next(hdev)` is a plain function called with `hdev->lock` held (`lockdep_assert_held`). It
  queues the head's start and sets the flag, or, when nothing is pending, clears the flag; a head
  whose start cannot be queued is completed and the next one tried.
- `mesh_send_done_sync()` sends its HCI command first, then takes `hdev->lock`, completes the head
  and calls `mesh_next()`; it no longer clears the flag first and has no destroy callback.
- `mesh_send_start_complete()`: on `-ECANCELED` it only completes the request (no lock, as
  before; from `send_cancel()` the lock is already held); on any other error it takes
  `hdev->lock`, completes and hands over.
- `send_cancel()` holds `hdev->lock` throughout and hands over when it dequeued a queued start or
  found the flag clear (the old condition).
- Lock order: `req_lock` → `hdev->lock` → (`unregister_lock`, `cmd_sync_work_lock`) as `mesh_send()`
  and `hci_clear_adv_sync()` already use; nothing takes `hdev->lock` under `cmd_sync_work_lock`; no
  HCI command under `hdev->lock`.

## Compared with our V3 1/5 (`266dda8daee0`, 2026-10-04, never sent)

The fix is V3 1/5 brought to today's tree, with four differences:

| point | V3 1/5 | the fix |
|---|---|---|
| dependency | states it assumes Hui Peng's 14831271 (a failed first queue removes the entry) | none: a stale entry from that leak can be completed or started out of order, as on base, but never has a second start queued [inferred] |
| `send_cancel()` hand-over | only `if (dequeued)` | `if (dequeued \|\| flag clear)`, keeping base's hand-over when idle |
| flag on a queued hand-over | left as the caller had it | set explicitly in `mesh_next()` |
| `hci.h` comment on `HCI_MESH_SENDING` | added | left out (one file, smaller for stable) |

## Compared with other authors' pending patches (as posted; the worker's `tmp/mesh/patchwork/*.mbox`, sha256 in its `tmp/mesh/results/SHA256SUMS`)

- **Baul Lee, v2 1/3–3/3 (14736726–8, 2026-08-07, `new`):**
  - 2/3 takes `hdev->lock` on the worker side and returns early on `-ECANCELED` in both destroy
    callbacks. That `-ECANCELED` rule is the same as ours in `mesh_send_start_complete()`, with one
    difference: his returns without completing the request (the entry stays listed), ours
    completes it as base does.
  - 2/3 differs on the race this fix is about: `mesh_send_done_sync()` still clears the flag before
    its locked section, and `mesh_next()` stays a separate destroy callback that takes the lock
    again, so the window between the clear and the hand-over stays open [inferred from his hunks].
    His start-error path has no hand-over; his base predates `71af682ba469`.
  - 2/3 adds `lockdep_assert_held()` to `mgmt_mesh_next()`, `mgmt_mesh_find()`, `mgmt_mesh_add()`,
    `mgmt_mesh_foreach()` and `mesh_send_complete()`. On today's tree `mgmt_cleanup()` (socket
    destructor) calls `mgmt_mesh_next()` without the lock, and the unregister path completes
    without it, so those assertions would fire unless 1/3 (removing `mgmt_cleanup()`) and his
    `-ECANCELED` rule come with them; we assert only in `mesh_next()`.
  - 3/3 adds a reference count to `mgmt_mesh_tx`. With it a second queued start no longer reads
    freed memory, but the same request would still be started twice [inferred].
  - Applicability: the series fails at 2/3 on `1081a6ef8f1e0` (`scripts/series-backport-check.sh
    bluetooth-next/master` → `FAILS at patch 2: Hunk #5 FAILED at 2327`), at the start-error hunk
    that `71af682ba469` changed.
- **14888791 (2026-10-14, `new`):** takes `hdev->lock` in `mesh_send_done_sync()`, `mesh_next()`
  and `mesh_send_start_complete()` while `mesh_next()` stays the destroy callback that
  `hci_cmd_sync_clear()` runs under `cmd_sync_work_lock`; lockdep reported `hdev->lock` taken under
  `cmd_sync_work_lock` in 9 of 12 `-s power` boots on 2026-10-21 (`results-2026-10-21.md`). It does
  not apply on CO-04 (`git apply --check`: `patch failed: net/bluetooth/mgmt.c:1094`).
- **Hui Peng, 14831271 (`new`; our Tested-by of 2026-10-06):** independent; applies on CO-04 and on
  CO-04 + CO-05.
- **Jiale Yao, 14864878 (`new`):** calls `mesh_send_done_sync()` and `mesh_next(hdev, NULL, err)`
  directly when `mesh_send_done()` cannot queue; does not apply on CO-04 (`mgmt.c:1131`), and its
  `mesh_next()` call would need the new signature and `hdev->lock`.
- **Cen Zhang, 14880941 (`new`):** removes `mgmt_cleanup()` from the socket destructor; independent;
  applies on CO-04.
- **Cen Zhang, 14661052 (2026-07-03, `new`):** dequeue on cancel; superseded in substance by the
  accepted `71af682ba469`; applies to none of the four bases.
- **Hui Peng, 14831256 v3 (2026-09-19, still `new` on patchwork):** withdrawn by its author the same
  day ("Please drop this patch"); it took `hdev->lock` in `mesh_send_sync()` and
  `mesh_send_start_complete()` and re-checked the entry against the list head.

## What the fix leaves as it was (pre-existing, outside this patch)

- `mesh_send_done_sync()` completes the head of the list, which need not be the request that was
  on air (a cancelled active request, or an entry left by the 14831271 leak): wrong-request
  completion stays (`STATE-MACHINE.md` I2/I8).
- At unregister, `hci_cmd_sync_clear()` still completes queued starts without `hdev->lock` (I6).
- `mesh_send_done()` ignores a failed queue (Jiale Yao's patch).
- `mesh_send_sync()`'s advertising-list locking is CO-05.
