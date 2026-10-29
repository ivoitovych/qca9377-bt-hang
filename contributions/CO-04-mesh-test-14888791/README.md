# CO-04 — syzbot's mesh_send_sync use-after-free: our independent fix

**State (2026-10-29):** **fix written and being tested; not sent.** "Bluetooth: MGMT: Fix
use-after-free in mesh_send_sync()" on bluetooth-next `1081a6ef8f1e0` (`patch/`, once packaged;
results in `experiments/results-2026-10-29.md`; comparison with our V3 1/5 and the other
pending patches in `experiments/comparison-2026-10-29.md`). Sending is the operator's decision.

**History:** opened 2026-10-21 to test another author's patch (14888791). It introduced a lockdep
circular-locking report (`hdev->lock` under `cmd_sync_work_lock`, 9 of 12 `-s power` boots, 0 on
base) and got no Tested-by (`experiments/results-2026-10-21.md`). On 2026-10-28 the operator
chose an independent fix instead, with no reply, review, Tested-by or Cc on that thread
(`log.md`).

**Target:** the Linux kernel, `net/bluetooth/mgmt.c`; syzbot's "KASAN: slab-use-after-free Read in
mesh_send_sync" (open; `Reported-by: syzbot+f20755f37da70df33a16@syzkaller.appspotmail.com`).

## The defect (source analysis; no reproducer, by the operator's decision of 2026-10-29)

`HCI_MESH_SENDING` is cleared without `hdev->lock` in `mesh_send_start_complete()` (failed start)
and `mesh_send_done_sync()` before `mesh_next()` queues the start of the list head. A concurrent
`mesh_send()`, which tests the flag under `hdev->lock`, can queue a start for its new entry in
that window, and `mesh_next()` then queues a second start for the same `mgmt_mesh_tx`. When the
first start fails the entry is freed, and the second start reads it (syzbot: 59 bytes into the
96-byte object, `send->cnt`).

## The fix

The flag stays set until the next start is queued or nothing is pending, and that decision is
made under `hdev->lock` (`mesh_next()` asserts it), from `mesh_send_done_sync()`, the start-error
path and `send_cancel()`. `hdev->lock` is never taken under `cmd_sync_work_lock`: on `-ECANCELED`
(dequeue, `hci_cmd_sync_clear()`) the callback only completes the request, as before, and
`mesh_send_done_sync()` has no destroy callback any more. Sent independently of CO-05: the two
apply in either order to the same tree.

## Next

1. Finish the runs (lockdep/KASAN, KCSAN 4-CPU, mesh-tester, preflight, the list bot's CI).
2. Outside review of the patch.
3. The operator's decision on sending; a `#syz test` on syzbot's thread also needs the operator's
   own word.
