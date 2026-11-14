# Task 4: CO-14, mesh sends queued at controller removal (2026-11-14)

QEMU guests (4 CPUs, KASAN, lockdep, kmemleak), BlueZ's `btvirt` (a virtual controller on vhci, in the guest only)
removed by terminating it. Nothing touched the host's Bluetooth. Nothing was sent. Raw logs `logs/runs/`
(`logs/SHA256SUMS`), batch summaries `logs/summary-*.txt`, per-kernel totals `logs/totals.txt`
(`harness/summarize.py`). Kernels (images `../img/bzImage-m-*`, tree `../lx`, branches in brackets):

| tag | tree |
|---|---|
| `m-tip` | bluetooth-next `da3cc02587c6` (detached) |
| `m-co04` | tip + CO-04, rebased on the tip by the other lane (`CO-04/patch-next-bare/`, `git am`: clean) [`lane1-co04`] |
| `m-fix` | `m-co04` + the patch below [`lane1-co14`] |

All three: the same config (BlueZ tester config, KASAN, lockdep, kmemleak; `harness/build-kml.sh`).

## 1. The backlog at removal (measured)

`harness/mesh-removal.py backlog`: a mgmt socket enables Mesh (experimental feature), Set LE, powers on, queues 3
Mesh Send (Count 20; at most 3 can be outstanding, a fourth gets BUSY 0x0a), waits D ms, **removes the controller**
(btvirt terminated: vhci closes, `hci_unregister_dev()`), then closes the socket. One boot = 4 controllers at four
values of D between 20 and 1400 ms (the same ten sets of offsets on every kernel, natural timing, no debug delays),
then 3 more without sends (see "kmemleak" below), then three kmemleak scans. 10 boots per kernel
(`harness/gen-spec-backlog.sh`, `harness/run-batch.sh`).

| | tip | tip + CO-04 | tip + CO-04 + fix |
|---|---|---|---|
| boots | 10 | 10 | 10 |
| Mesh Sends accepted | 120 | 120 | 120 |
| completed before / during the removal | 20 / 7 | 19 / 9 | 16 / 12 |
| **never completed** (no Mesh Packet Complete ever) | **93** | **92** | 92 |
| **kmemleak objects from `mgmt_mesh_add()`** | **86** | **86** | **0** |
| **kmemleak HCI sockets (`hci_sock_create`)** | **22** | **23** | **0** |
| boots with a leak | 10 of 10 | 10 of 10 | 0 of 10 |
| longest `close()` of the mgmt socket | 88 us | 27 us | 113 us |
| KASAN / WARNING / BUG / hung task | 0 | 0 | 0 |
| lockdep cycles | 0 | 0 | 0 |

**Verdict, measured:** on the tip and on tip + CO-04 a mesh send queued when the controller is removed **never
completes, is never freed, and pins the mgmt socket**; closing the socket returns at once (tens of microseconds),
nothing blocks, and the socket's memory stays. CO-04 changes nothing in this respect (86 and 86 leaked objects).
Per boot the never-completed count equals the kmemleak count in 8 of 10 boots on the tip (all but boots 1 and 7:
9 of 11 and 5 of 10) and in 8 of 10 on CO-04 (all but boots 6 and 9: 8 of 11 and 5 of 8). kmemleak reports an
object only after the memory that pointed to it is gone and the scans have seen it unchanged, so it under-reports
and the never-completed count is the upper bound; it never reported more than that count.

**Controls** (`harness/spec-controls.txt`, `logs/summary-controls.txt`; 4 controllers + 3 trailing per boot): all
sends completed before the removal (`complete`; tip 2 boots, CO-04, fix 1 each) and no sends (`nosend`; one boot on
each kernel): 0 kmemleak objects, 0 sockets everywhere. The harness has no false positive on these paths.

**kmemleak and the trailing iterations:** a single controller removed and scanned alone reported nothing at all
(three tip runs, 17 s of scans after the removal), while the same sequence repeated reported the leaked objects.
The leaked objects are referenced from the freed `hci_dev` until its memory is out of the way, so the harness
removes three more controllers without sends after the measured ones (`--trailing 3`) and scans three times, 8 s
apart. With this the count matches the sends that never completed. A first development run with 10 iterations and
no trailing ones reported 21 of 30 (the last iterations were still shadowed).

## 2. Where it is (source, tip `da3cc02587c6`) and the fix

- A Mesh Send is added to `hdev->mesh_pending` (`mgmt_util.c:428`, `mgmt_mesh_add()`), taking a reference on its
  socket (`:426`, `sock_hold()`), freed and released only by `mgmt_mesh_remove()` (`:435-436`).
- Only the transmission whose start is queued is freed at unregister: `hci_unregister_dev()` calls
  `hci_cmd_sync_clear()` (`hci_core.c:2805`) which calls `mesh_send_start_complete(-ECANCELED)` for the queued
  `mesh_send_sync`. The ones behind it were never queued.
- `mgmt_index_removed()` (`mgmt.c:9894`) cancels `mesh_send_done` (`:9925`) and stops there; no code frees the list.
- `mgmt_cleanup(sk)` (`mgmt.c:11106`, called at the socket's close) completes the requests of the socket, but only
  for controllers in `hci_dev_list`; `hci_unregister_dev()` removed this one from it first (`hci_core.c:2789`).

**The fix** (`patches/on-co04/0001-Bluetooth-MGMT-Free-pending-mesh-sends-when-the-cont.patch`, 9 lines in
`mgmt_index_removed()`): after `cancel_delayed_work_sync(&hdev->mesh_send_done)`, with `hdev->lock` held as
`hci_unregister_dev()` holds it (`hci_core.c:2814-2816`):

```
while ((mesh_tx = mgmt_mesh_next(hdev, NULL)))
	mesh_send_complete(hdev, mesh_tx, true);
```

silent, as `mgmt_cleanup()` is. It does not depend on CO-04: `git apply --check` is clean on the bare tip as well.
checkpatch `--strict --no-tree`: only the missing Signed-off-by. No Signed-off-by, no attribution.

**Base against patched** (section 1): kmemleak mesh objects 86 (tip), 86 (CO-04), **0** (fix); sockets 22, 23, **0**;
10 of 10 boots clean with the fix; controls clean on all three.

**Regression runs:**
- BlueZ's `mesh-tester` (master, 10 cases; the project's prebuilt binary), 3 runs on each kernel
  (`logs/summary-testers.txt`): **8 of 10 passed in every one of the 9 runs**, the same two cases failing on tip,
  CO-04 and fix alike (the baseline the CO-04 work recorded: 8/10); no kernel report line in any.
- `mgmt-tester` (515 cases): **not completed.** The first attempt (900 s limit) timed out on the tip; a second ran
  at about 75 minutes per kernel (217 cases done on the tip after 31 minutes; log
  `tester-mgmt-tester-m-tip-2.log`), too long for three kernels, and I stopped it. A first subset with a two-word
  prefix matched every "Set" case and was stopped after 30 minutes (`tester-mgmt-subset-m-co04-Set_powered.log`).
  The subsets that ran (`logs/summary-mgmt-subset.txt`): "Remove" (32 cases) tip + CO-04 30/32, +fix 31/32;
  "Suspend" (9 cases) 9/9 on both. The failures are `LL Privacy - Remove Device 3 (Disable RL)` on both
  (`test failed`) and, on CO-04 only, `LL Privacy - Remove Device 4 (Disable Adv)` (`test timed out`): advertising and
  RPA-list cases with no mesh involved, in a code path the fix does not enter (an empty `mesh_pending`); I did not run
  the tip for these subsets, so I cannot say whether the first one fails there too.

## 3. The lockdep cycle (`unregister_lock` against `cmd_sync_work_lock`, `mesh_next()` from `hci_cmd_sync_clear()`)

**Mine, measured:** on the tip and on tip + CO-04, **0 lockdep reports in 60 boots each**:
backlog (10 boots, above); a fine sweep of the removal time around the end of a transmission, one Mesh Send
(Count 20), 10 boots x 12 controllers, offsets 470 to 534 ms in 1 ms steps (`logs/summary-lockdep.txt`); a
controller that stops answering (SIGSTOP with a Set Local Name pending) and is then removed, 10 boots x 6
controllers (`logs/summary-hung.txt`). **I did not reproduce it.** The other lane's log has it on the tip, 2 of 35
boots (`UnregSweep-plain-17`, `-28`; their `CO-04/circular-count.txt`: tip 2/35, CO-04 0/35, CO-05 2/35, both
0/35). Their splat lines are quoted in `co04-message-note.md`.

**Inferred from the source why it is rare:** it needs `hci_cmd_sync_clear()` (`hci_sync.c:675`) to find a queued
`mesh_send_done_sync` on `cmd_sync_work_list` and run its destroy callback `mesh_next()` (the tip's
`hci_cmd_sync_queue(hdev, mesh_send_done_sync, NULL, mesh_next)`, `mgmt.c:1145`), which queues a command and takes
`unregister_lock` (`hci_sync.c:734`) under `cmd_sync_work_lock`; the other order is `hci_cmd_sync_submit()`
(`:734`, `:749`). But `hci_cmd_sync_clear()` first cancels the pending request and `cancel_work_sync()`s the
worker (`:680-681`): a running worker finishes the queue, so the list walk finds an entry only when the worker is
still queued, not started. A stuck controller does not produce that (my third scenario); a ~microsecond race does.

**It is CO-04's to fix, and CO-04's message should name it.** CO-04 gives `mesh_send_done_sync()` no destroy
callback, which removes the only path from `hci_cmd_sync_clear()` to `hci_cmd_sync_queue()` (0 of 35 on their sweep
with CO-04 against 2 of 35 on the tip). Its message now names an inversion only for the earlier proposal.
`co04-message-note.md` has a suggested paragraph and the reasoning; the `Fixes:` line should stay the UAF's.

## Open

- The lockdep cycle is not reproduced by me; only the other lane's log shows it.
- `mgmt-tester` not run in full on any of the three kernels; the subsets above.
- kmemleak under-reports in some boots (counts above); the never-completed count is the upper bound.
- The fix completes the pending sends silently. Whether userspace should get Mesh Packet Complete (or an error)
  for them before the Index Removed event is a semantics question for the maintainers; the patch follows
  `mgmt_cleanup()`.
- Not tested: a controller removed while the mgmt socket's own pending command (`Set Local Name`) was queued is
  covered only by the `hung` runs (no leak judgement there: `--no-kml`).
- Disk: free space stayed above 25 GB (checked before each build); `build/kobj-kml` (0.8 GB) and `build/kobj`
  are mine.
