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

## 2026-10-21, worker W4 (QEMU only), about 05:15 to 07:45 local — the series written and tested
On the operator's go. Two patches on bluetooth-next `27731ba09195` (`patch/`): the lock in
`mesh_send_sync()`, and CO-26's early return as 2/2 (kept separate: no client-visible change,
and 1/2 stays small for stable). Mesh-path assertion warnings 3 → 0; `mesh_send_sync()` KCSAN
reports 5 of 45 boots → 0; mgmt-tester 503 cases and mesh-tester verdicts unchanged; no new
lockdep report. Full account: `experiments/results-2026-10-21.md`; raw in `tmp/co05-w4/`.

## 2026-10-21 08:00 local — re-checked before entering the dossier
`tmp/co05-check/recheck.sh assert S-base` and `S-p12`: base 3 warnings from `mesh_send_sync`,
patched clean, both 8/10 on master mesh-tester. The drafts checked for tool or model names and
trailers (none).

## 2026-10-28 — freshness walkthrough
- **Still unfixed upstream; still applies.** Both patches apply to bluetooth-next `47d4d9f67e92`
  with 2-line offsets (`scripts/series-backport-check.sh bluetooth-next/master patch/*`). The only
  change to the advertising-list functions since October, `f7f0d0a9eb6e4` (Add Extended
  Advertising Parameters leak, 10-14), is already in the tested base `27731ba09195`. No pending
  patch on patchwork touches `mesh_send_sync()`.
- **A neighbour, not a conflict:** Weihong Guan's 14910392 (10-23, `new`, `hci_sync.c`) makes
  two ext-adv commands use `adv->handle`; it adds `hci_find_adv_instance()` lookups on the sync
  worker without `hdev->lock`, the same class as I12, in other functions.
- **The mesh queue is stalled** (CO-06's log of today): four other mesh fixes wait with no
  maintainer reply; the maintainers applied only Pauli Virtanen's timeout-units fix in this area.
- **Missing before a send:** an outside review of the written patches (the reviews of 10-21
  were on the shape, before they were written); `scripts/kernel-preflight.sh` and
  `scripts/bot-ci-local.sh` on `47d4d9f67e92`; a test-report paragraph; the operator's decision,
  including whether to send while the mesh queue is stalled.

## 2026-10-28 — six outside reviews of `24d76cd` (relayed by the operator; not consent)
All six: the locking of 1/2 is right for its scope (`req_lock` → `hdev->lock` as in
`hci_clear_adv_sync()`; no wait under the lock; only the instance number crosses the unlock); keep
2/2 separate; no damage reproducer needed. Points to act on, each to be verified first:
1. **Reviewer 6, a pre-existing defect inside our hunk:** `mesh_send_sync()` returns
   `MGMT_STATUS_BUSY` (0x0a, positive) to `mesh_send_start_complete()` → `mgmt_status(err)`, which
   reads a positive value as an HCI status index, so the client may get a wrong status. Proposed:
   a separate one-line patch returning `-EBUSY`, `Fixes: b338d91703fa`. **Verify in source.**
2. **Reviewers 2 and 5: Hui Peng's earlier proposal** (2026-09-19, "Fix mesh_tx Use-After-Free and
   leak in mesh_send()", v3) reportedly took `hdev->lock` in `mesh_send_sync()` too; reviewer 2
   says it was withdrawn as superseded by `71af682ba469`. **Verify** (which version our Tested-by of
   10-06 was on, whether `71af682ba469` exists, its state) and record the overlap.
3. **Reviewer 4:** patch 1's testing paragraph should say the 45-boot KCSAN run had both patches.
4. **Reviewers 2 and 5:** consider `Fixes: b338d91703fa` on 2/2. **Reviewer 6:** 2/2's first
   sentence could read "When hci_add_adv_instance() fails, mesh_send_sync() keeps the error and
   carries on".
5. **Reviewers 3 and 5:** `hci_schedule_adv_instance_sync()` still reads advertising state
   unlocked, and `mesh_tx` is dereferenced before the lock — both pre-existing; say so, and review
   CO-05 together with CO-04's coming fix of the same function.
Then: regenerate on today's base, preflight, the bot's CI, cover letter, recipients.

## 2026-10-28/29 — the review points checked in source (bluetooth-next `1081a6ef8f1e0`)
- **Point 1, `MGMT_STATUS_BUSY` (reviewer 6): true in the code, no observable effect; no third
  patch.** `grep -n -A12 "^static u8 mgmt_status(int err)" net/bluetooth/mgmt.c` → `314: static u8
  mgmt_status(int err)` … `319: if (err < ARRAY_SIZE(mgmt_status_table))` / `320: return
  mgmt_status_table[err];`. Index 0x0a of the table (`grep -n -A70 "^static const u8
  mgmt_status_table"`, line 218 is index 0) is line 228: `MGMT_STATUS_NO_RESOURCES, /* Max Number
  of SCO Connections */` — non-zero. `mesh_send_start_complete()` uses `mgmt_err` only as a
  condition (`if (mgmt_err) {`), so `MGMT_STATUS_BUSY` takes the same branch as `-EBUSY` would, and
  the only event sent there, Mesh Packet Complete, carries the handle alone
  (`mgmt_event(MGMT_EV_MESH_PACKET_CMPLT, hdev, &handle, sizeof(handle), NULL)`, `mgmt.c:1092`). No
  status reaches user space, so the reviewer's "the client may get a wrong status" does not happen.
  A patch changing only the internal value would cost a maintainer's time for nothing visible.
- **Point 2, Hui Peng's earlier proposal (reviewers 2 and 5): confirmed.** Patchwork 14831256,
  "[v3] Bluetooth: MGMT: Fix mesh_tx Use-After-Free and leak in mesh_send()", 2026-09-19 11:25,
  took `hci_dev_lock(hdev)` in `mesh_send_sync()` around the add and in
  `mesh_send_start_complete()`, and re-checked the entry against `mgmt_mesh_next(hdev, NULL)`
  (`python3 -I tmp/mesh/pw-show.py tmp/patchwork/patch-14831256.json`, its diff). The bot could not
  apply it (`patch failed: net/bluetooth/mgmt.c:2306`); its author withdrew it at 11:55 the same
  day ("Please drop this patch … 71af682ba469 … fixed that on 2026-09-15, and fixed it better") and
  re-sent only the leak half as 14831271, the patch our Tested-by of 2026-10-06 is on (our reply is
  comment 2 of 14831271). `71af682ba469` exists: Lee Jones, "Bluetooth: mgmt: Dequeue pending
  mesh_send_sync entries on cancel", patchwork 14818191, `accepted`
  (`python3 -I scripts/patchwork-state.py --files 14818191` → `accepted … commit=71af682ba469…`).
  14831256 still shows `new` on patchwork. So the I12 lock was proposed once, inside a withdrawn
  patch, and never applied; the cover letter credits it by link.
- **Points 3 to 5** go into the regenerated messages and the cover letter (`patch/`).

## 2026-10-29 — refreshed on bluetooth-next `1081a6ef8f1e0`, re-tested, packaged
- **Rebased:** `git am` of the 2026-10-21 pair on `1081a6ef8f1e0` (fetched that day; one new commit
  since `47d4d9f67e92`, btintel): clean. Nobody else fixed it meanwhile (pre-send check, `git log
  -G`, patchwork and lore searches: `experiments/results-2026-10-29.md`).
- **Review points applied:** 3 — the test numbers left 1/2's message for the cover letter's test
  paragraph, which says the KCSAN boots had both patches; 4 — `Fixes: b338d91703fa` on 2/2; its
  first sentence already reads as reviewer 6 proposed; 5 — the cover letter says
  `hci_schedule_adv_instance_sync()` stays unlocked and that the `mgmt_mesh_tx` lifetime is CO-04's
  separate fix; 1 and 2 as recorded above.
- **Re-tested** on 4-CPU guests: lock-assertion warnings 3 → 0; KCSAN 45 boots, races in
  `mesh_send_sync()` 1 boot → 0; no lockdep/KASAN/WARNING in 48 boots per image; tester verdicts
  unchanged; CO-26's trace as before. Also tested together with CO-04's fix.
- **Checks:** preflight clean; pre-send OK; the list bot's checks PASS on the patched side
  (VerifyFixes first failed on the harness's history depth, then passed with older history); its
  base side stalled in a clone and was stopped (no patched failure to compare).
- **Package:** `patch/` (cover letter, 1/2, 2/2, recipients, reviewer questions); the 2026-10-21 set
  in `patch/2026-10-21/`. Ready for an outside review round; not sent.
- **Not re-run, with reasons:** the 503-case one-by-one mgmt-tester (the bot's 515-case run with the
  series replaces it); the `MGMT_STATUS_BUSY` early return of 1/2 (no test fills every advertising
  set first; the path only unlocks and returns).
