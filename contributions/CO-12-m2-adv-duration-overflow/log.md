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
