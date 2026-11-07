# CO-12 references

**Our record:**
- `docs/STATUS.md`, the M-2 row.
- `docs/mesh-tester-ci/research-review-2026-10-05.md`: "the duration overflow stays separate
  and needs a timeout design, not a clamp".

**Reviews:**
- `reviews/2026-10-20T2332Z-source-investigation-task.md`, item 5.
- `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI3.

**Source,** bluetooth-next `27731ba09195`:
- `net/bluetooth/hci_sync.c:1702`;
- `include/net/bluetooth/mgmt.h:565`;
- `include/net/bluetooth/hci_core.h:252` (`struct adv_info`, `__u16 timeout`).

**Upstream commits:**
- `8a8d51eeedeb` (bluetooth-next; `87a49b610708` in bluetooth);
- `cba6b758711c` (2021, the line's origin).
