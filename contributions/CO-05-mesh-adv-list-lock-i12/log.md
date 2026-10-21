# CO-05 log

Append-only. Newest last.

## 2026-10-05 — inferred, then shown
- **Inferred:** the state-machine document named I12 as a locking-contract violation. The
  research review asked for it to be reproduced before any redesign.
- **Shown:** the same day's gates showed it in QEMU (`STATE-MACHINE.md`, update block):
  - four call paths fire the added lockdep assertion;
  - KCSAN reports races in 5 of 15 boots on bluetooth-next, and 4 of 15 on our v3;
  - no KASAN report.
- **Results file:** `docs/mesh-tester-ci/gates-2026-10-05.md`.

## 2026-10-20 — still unfixed upstream
- **14888791** (Igor Putko) adds `hdev->lock` elsewhere in the mesh path, not in
  `mesh_send_sync()`.
- **Recorded** as CO-05 in the contribution list, and as item 4 of the source investigation
  task.

## 2026-10-21 — reviewer 1
- **Agrees:** the lock belongs around the list change.
- **Proposed:** "then queue the command-sync work". That misreads the context:
  `mesh_send_sync()` is the command-sync work.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI5.

## 2026-10-21 — dossier opened
The gate results are tracked as `docs/mesh-tester-ci/gates-2026-10-05.md` (ported to `main`
in `9588c99`); the `tmp/` copy is the working original.

## 2026-10-21 — reviewers 2, 3 and 4 on the shape; one more defect in the same function
- **The shape, agreed:**
  - `hdev->lock` from the capacity check through the add;
  - copy the instance ID, not an `adv_info *`;
  - unlock before `hci_schedule_adv_instance_sync()` or any command wait;
  - one patch per call site;
  - add `lockdep_assert_held()` to the helpers only after all callers are fixed.
- **Reviewer 2:** a failed transaction's cleanup must check that the instance is still its
  own.
- **New, reviewer 4, confirmed in bluetooth-next `mgmt.c:2342–2379`:** a failed
  `hci_add_adv_instance()` sets `err` and goes on. If `instance` stays nonzero, the function
  returns the scheduler's result instead: the error is lost, and an instance that was never
  added is scheduled. Recorded as CO-26, to be fixed in the same patch (return the error at
  once, under the lock).
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV4
  and RV5.
