# CO-05 — Mesh I12: advertising list changed without `hdev->lock`

**State:** reproduced in QEMU (2026-10-05). No patch is written yet.

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

1. Draft the mesh-path patch on bluetooth-next.
2. Run the same lockdep assertion and KCSAN 4-CPU runs, with and without it, through our
   kernel pre-send checks (`scripts/kernel-preflight.sh`).
3. Package it with a test report. Nothing is sent without the operator's word.
