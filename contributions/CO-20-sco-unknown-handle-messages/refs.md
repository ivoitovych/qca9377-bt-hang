# CO-20 references

**Our record:**
- `docs/issues.md`, U8 (the "corrupted SCO packet" lead).
- `reviews/2026-10-20T2309Z-contribution-opportunities.md`, CO-20.
- `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI2.

**Captures** (raw, git-ignored): the HCI capture directories cover the current boot. The six
hang-ups are at 2026-10-20 11:53:08, 11:55:45, 12:42:12 and 12:52:35, and 2026-10-21 00:12:33
and 00:19:49 (local time).

**Source:**
- bluetooth-next `27731ba09195`: `net/bluetooth/hci_core.c:4043`, and `sco_recv_scodata()` in
  `sco.c`.
- Ubuntu `7.0.0-38`: `drivers/bluetooth/btusb.c` — `btusb_validate_sco_handle()` (1344),
  `btusb_recv_isoc()` (1372), the message (1668).
- In bluetooth-next the driver is split: `drivers/bluetooth/btusb_main.c:1842`.

**Upstream:** BlueZ #2562, the AX211 comment of 2026-10-13.

**Tools:** `scripts/sco-ledger.sh`, `scripts/capture-window.sh`.
