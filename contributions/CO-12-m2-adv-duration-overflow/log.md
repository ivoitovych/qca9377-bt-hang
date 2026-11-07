# CO-12 log

Append-only. Newest last.

## Before 2026-10-13 (mesh work) — noted
`u16 duration = adv->timeout * MSEC_PER_SEC` overflows above 65 s. Recorded as `M-2`, a
hypothesis, and as step (6) of the mesh order.

## 2026-10-13 — narrowed
`87a49b610708` (Pauli Virtanen, 2026-10-05) made the mesh case use milliseconds directly. The
truncation remains for ordinary extended advertising (STATUS, M-2).

## 2026-10-21 — confirmed in source
- **The read:** bluetooth-next `27731ba09195`, `hci_sync.c:1702` and `mgmt.h:565`.
- **The arithmetic,** worked out: 66 s → 460 ms; multiples of 65.536 s → 0.
- **Reviewer 1** agreed and quoted the line's older form.
- **Full record:** `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI3.

## 2026-10-21 — dossier opened

## 2026-10-21 — reviewers 2, 3 and 4; the reach confirmed
- **The arithmetic:** reviewer 4's table, recomputed and holding:

  | timeout | HCI duration units |
  |---|---|
  | 65 s | 6500 |
  | 66 s | 46 |
  | 120 s | 5446 |
  | 655 s | 6517 |
  | 656 s | 64 |
  | 8192 s | 0 (unlimited) |
  | 65535 s | 6453 |

- **The reach:** MGMT Add Advertising (`mgmt.c:9108–9121`) has no timeout cap; it checks only
  "powered" and "busy".
- **The trap,** agreed by all three: a `u32` fixes 66 to 655 s only. A test above 655 s keeps a
  partial fix from passing.
- **The design** (reviewers 3 and 4): above the HCI field's range, program no controller
  duration and let a host deadline end the advertising, through the same disable, remove and
  event path.
- **The emulator** times out at `duration * 10` (`emulator/btdev.c`, per reviewer 4), so a 66 s
  request shows the 460 ms expiry quickly.
- **Full record:** `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV7.

## 2026-11-01 (night) — tests reworked, rebased, stable forms
QEMU only; work area (local, raw logs, SHA256SUMS) `/root/exp/agent-work/co12-rework-20261101/`;
branches `co12-rework/*` in the cache repositories, not pushed. Nothing sent.
- **Tests:** 15 new mgmt-tester cases and 1 mesh-tester case (BlueZ style, no Signed-off-by).
  Each reads the Duration the emulator receives, checks the instance is still listed at 2 to
  5.5 s, and where removal is due checks Advertising Removed between Duration×10 ms − 50 ms and
  +1000 ms. The 1 s controls now pass as tests. Values 0, 65, 66, 655, 656, 6357, 8192, 65535,
  a replacement while a timeout is pending (the old deadline never fires; the new instance goes
  3003 ms after its own enable), two instances, and mesh. Base fails every case at 66 s and
  above (Duration 46, 6517, 64, 0, 0, 6453); the clamp passes all, 3 runs each. The 113 other
  "Add" cases pass on every kernel. Above 655 s the cases expect 0xffff, i.e. they pin the clamp.
- **Real expiry, research-only cases (not for submission):** with the clamp, removal at 65001,
  66001, 655004 and 655354 ms for 65, 66, 655 and 656 s.
- **A second bug, found by these tests and checked in mainline source:** `read_adv_features()`
  keeps an instance only if its number is at most `hdev->adv_instance_cnt` (how many instances
  exist), although its own comment says 1 to `le_num_of_adv_sets` (`mgmt.c:8862-8863` in
  mainline `cbbddb6b08cc`). So once instance 1 has gone, instance 2 disappears from Read
  Advertising Features with no Advertising Removed event. From `b338d91703fa` (mesh, 2022), in
  6.1.y to bluetooth-next. A one-line fix passes 3/3 runs and 128/128 cases, checkpatch
  `--strict` clean, applies to 7.3.y to 6.1.y. No prior patch found by subject. Registered as
  CO-38.
- **Cen Zhang's series 1197214 (14927631 + 14927632):** the clamp conflicts with patch 1/2 on the
  duration hunk in either order; both resolutions give the same tree, and the tests pass on it.
  A clamp form for on top of the series is ready.
- **Stable forms:** the 7.3.y form (no mesh ternary) applies to 7.3.y, 6.18.y, 6.12.y, 6.6.y and
  6.1.y and builds with W=1 on 7.3.y; on 5.15.y and 5.10.y the code is in
  `__hci_req_enable_ext_advertising()` (`hci_request.c`), and a separate form applies there and
  builds on 5.15.y.
- **Commit message revised:** the 655.35 s limit stated, the history line corrected (the
  computation since `10bbffa3e88e`; `f16a491c65d9` changed only the guard), the bluetoothd scope
  stated, and the three options (clamp, reject, per-instance host deadline) named below the
  `---`. checkpatch `--strict` clean on all forms.
