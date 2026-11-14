# CO-14 — mesh at device removal: pending sends leak with their socket (M-4); the lock-order cycle (M-5)

**State (2026-11-14): reproduced in emulation; a fix written on top of CO-04; nothing sent.**
`fix-20261114/` (copied from `/root/exp/agent-work/lane1-btusb-20261114/task4/`; `RESULTS.md`
there has every command and result; `logs/totals.txt` the counts). STATUS rows `M-4`, `M-5`;
`docs/issues.md` the evidence.

**M-4, the leak** (bluetooth-next `da3cc02587c6`): a Mesh Send still on `hdev->mesh_pending` when
its controller is removed is never completed or freed, and keeps its mgmt socket referenced:
`mgmt_index_removed()` only cancels the done work, and `mgmt_cleanup()` at socket close walks
`hci_dev_list`, from which the controller is already gone. QEMU, BlueZ's `btvirt`, controllers
removed mid-backlog, kmemleak, 10 boots per kernel, 120 sends each:

| | tip | tip + CO-04 | CO-04 + fix |
|---|---|---|---|
| sends never completed | 93 | 92 | 92 (freed silently, as `mgmt_cleanup()` does) |
| kmemleak mesh objects | 86 | 86 | 0 |
| leaked sockets | 22 | 23 | 0 |
| boots with a leak | 10 of 10 | 10 of 10 | 0 of 10 |

Controls (every send completes first, or none sent): nothing leaks on any kernel. kmemleak only
reports these after further allocation and freeing, so the harness removes three more
controllers after the measured ones; the lockdep and stopped-controller runs did not
(`trailing=0`), which is why they show 0 leaks with 60 to 88 sends never completed: not a
contradiction, a scan that could not see it (checked on copy: `m-tip-H-1.log` has
`trailing=0 … never_completed=6 kmemleak_mesh=0`).

**The fix** (`fix-20261114/patches/on-co04/0001-Bluetooth-MGMT-Free-pending-mesh-sends-when-the-cont.patch`,
9 lines in `mgmt_index_removed()`; applies to the bare tip too; checkpatch: only the missing
Signed-off-by). mesh-tester 8 of 10 on all three kernels (9 runs, the same two failures
everywhere). mgmt-tester only in part: the full run takes ~75 min per kernel and was stopped at
217 of 515 on the tip; "Remove" 30/32 on CO-04 and 31/32 with the fix, "Suspend" 9/9 on both; the
failing `LL Privacy - Remove Device 3` fails on both and does not involve mesh (not run on the
tip). **Before a send:** the full mgmt-tester on CO-04 vs CO-04 + fix.

**M-5, the lock-order cycle:** seen by another lane's unregister sweep in 2 of 35 boots on the tip,
0 of 35 with CO-04 (`../CO-04-…/send-20261114/circular-count.txt`); not reproduced here in 60
boots per kernel over three other scenarios. From the source it needs a queued
`mesh_send_done_sync` still on the list when `hci_cmd_sync_clear()` walks it, i.e. the sync worker
queued but not yet started. CO-04 removes that destroy callback; `fix-20261114/co04-message-note.md`
argues CO-04's commit message should name the cycle and gives wording.

**Open for the maintainers (and the operator):** whether user space should get a Mesh Packet
Complete or an error for the freed sends (the patch follows `mgmt_cleanup()`: silent).

**Changed on copy:** `in/co04.patch` (the CO-04 input the work area used) and one mgmt-tester log
line (qemu naming the process that stopped it) carry the operator's address / "(the harness)".
