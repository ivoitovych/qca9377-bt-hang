# CO-05 — Mesh I12: advertising list changed without `hdev->lock`

**State (2026-10-29):** **send package ready for an outside review round; not sent.** Two patches
and a cover letter on bluetooth-next `1081a6ef8f1e0` (`patch/`, with CO-26 as 2/2); the 2026-10-21
set is in `patch/2026-10-21/`. On today's base: mesh-path lock warnings 3 → 0, KCSAN boots with a
race in `mesh_send_sync()` 1 → 0 of 45, tester verdicts unchanged, preflight clean, the list bot's
checks pass (`experiments/results-2026-10-29.md`). The operator decides on sending.
(Reproduced in QEMU 2026-10-05; first written and tested 2026-10-21.)

**Target:** the Linux kernel (`net/bluetooth/mgmt.c`, and separately three other callers).

**Comes from:** the mesh state-machine work (`docs/mesh-tester-ci/STATE-MACHINE.md`, invariant
I12).

## The finding

- **The defect:** `mesh_send_sync()` calls `hci_add_adv_instance()` without `hdev->lock`,
  which the function requires. The contract is in `hci_core.c` and dates from
  `d2609b345ebf`, 2015.
- **Lock assertions:** with `lockdep_assert_held(&hdev->lock)` added to the add and remove
  functions, four call paths fire on bluetooth-next:
  - mesh send;
  - ISO broadcast (`hci_add_per_instance()`);
  - Set LE off;
  - the advertising timeout (`hci_clear_adv_instance_sync()`).
- **KCSAN:** on a 4-CPU guest it reports races on the list between Add Advertising (locked)
  and `mesh_send_sync()` (unlocked), in 5 of 15 boots.
- **No damage shown:** no KASAN report, no corruption.
- **Unlocked since:** `b338d91703fa` (2022) for mesh; `eca0ae4aea66` and `c249ea9b4309`
  (2022) for the others.
- **Nobody has written the fix.** The pending 14888791 (CO-04) does not touch
  `mesh_send_sync()`.

## The shape (our rule; reviewer 1 agrees in substance)

`mesh_send_sync()` already runs on the command-sync worker and sends its HCI commands
synchronously:
- take `hdev->lock` for the list change and the list walks, after `req_lock`;
- never hold `hdev->lock` across an HCI command.

The other three paths get their own patches, not folded into a mesh series (the 2026-10-05
review).

## Next

Done on 2026-10-29 (`log.md`): every point of the 2026-10-28 reviews applied or answered; rebased
and re-tested on `1081a6ef8f1e0`; preflight, pre-send and the list bot's checks; cover letter with
the test report; recipients. It fits CO-04's fix: the two apply in either order, and their
combination was tested too.
1. An outside review round of `patch/` (questions in `patch/README.md`).
2. The operator's decision on sending (and whether together with CO-04, or after it). Nothing is
   sent without the operator's word.
