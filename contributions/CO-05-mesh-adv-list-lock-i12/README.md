# CO-05 — Mesh I12: advertising list changed without `hdev->lock`

**State:** **patch written** (2026-10-21), with CO-26 as patch 2/2: `patch/`; results and the
re-check in `experiments/results-2026-10-21.md`. The mesh-path lock warnings go 3 → 0, the
`mesh_send_sync()` KCSAN reports 5 → 0 of 45 boots; tester verdicts unchanged. Not sent: the
operator decides. (Reproduced in QEMU 2026-10-05.)

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

Done on 2026-10-21: the patches drafted (`patch/`) and the lockdep-assertion and KCSAN 4-CPU runs,
with and without them (`experiments/results-2026-10-21.md`). Still to do (2026-10-28, `log.md`):
1. an outside review of the written patches (the reviews of 10-21 were on the shape);
2. `scripts/kernel-preflight.sh` and `scripts/bot-ci-local.sh` on today's bluetooth-next;
3. a test-report paragraph, then the operator's decision. It now also has to fit the
   independent fix for the mesh use-after-free planned in CO-04, which touches the same
   function. Nothing is sent without the operator's word.
