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
