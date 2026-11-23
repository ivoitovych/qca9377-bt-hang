# CO-04 — syzbot's mesh_send_sync use-after-free: our independent fix

> **2026-11-23: overtaken upstream; not to be sent.**
> - **The fix.** The Bluetooth maintainer's "Bluetooth: mgmt: Fix mesh transmission locking and
>   lifetime" was posted 11-17 and accepted 11-18 as patchwork 14998382. It is bluetooth-next
>   `1d7a52778858`, committed 11-19. By its message, it:
>   - clears `HCI_MESH_SENDING` only together with the removal of the transmission;
>   - queues the cmd_sync entries by handle instead of a raw `mesh_tx` pointer;
>   - does not take `hdev->lock` from `-ECANCELED` callbacks.
>
>   That is this patch's mechanism and design. Its sources are Sashiko reports on the other
>   authors' mesh patches.
> - **What is left of ours:** this dossier's harness (the UnregSweep lockdep sweep, the cancel
>   cases), run on bluetooth-next `cf357cfc025e` to look for a gap. That would make a small new
>   patch, or a Tested-by on the applied commit (the operator's call).
> - **Records:** `docs/STATUS.md` (top, M-5); `../../reviews/2026-11-22T1240Z-kernel-contributions-review-worklog.md`
>   F-41.
>
> The `Closes:` and `Cc: stable` trailers in `review-fixes-20261114/` are moot with it.

> **Note of 2026-11-16 (newer than the state of 2026-10-29 below):** the package to send is
> `review-fixes-20261114/` (mail form in `patch/`, `git am` form in `patch-bare/`), and
> `send-20261114/` is superseded; the line "The send file is `patch/0001-…`" in
> `send-20261114/README.md` names that older package. The code is unchanged since 10-29; the
> 11-14 refresh on `da3cc02587c6` found a lockdep cycle at controller unregister on the tip in
> 2 of 35 boots, none with this patch. See the table "What to send" in `../README.md`.

**State (2026-10-29):** **send package ready for an outside review round; not sent.** "Bluetooth:
MGMT: Fix use-after-free in mesh_send_sync()" on bluetooth-next `1081a6ef8f1e0` (`patch/`; results
in `experiments/results-2026-10-29.md`; comparison with our V3 1/5 and the other pending patches in
`experiments/comparison-2026-10-29.md`). No lockdep/KASAN report in 48 boots per image, verdicts
unchanged, preflight clean, the list bot's checks pass; the earlier proposal's lock inversion
re-shown on today's base (8 of 12 boots). Not reproduced, by the operator's decision. Sending is
the operator's decision.

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

1. Outside review of `patch/` (questions in `patch/README.md`).
2. The operator's decision on sending; a `#syz test` on syzbot's thread also needs the operator's
   own word.
