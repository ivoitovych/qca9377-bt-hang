# CO-02 references

**Our record:**
- `docs/issues.md`, U7.
- `docs/STATUS.md`, the U7 row.
- `evidence/exhibits/060-hfp-codec-switch-reply-before-old-link-gone.md`: the timing table and
  its commands.
- `docs/userspace-upstream-check-2026-10-03.md`, §U7: the PipeWire tracker and master
  check.
- `reviews/2026-10-20T2332Z-source-investigation-task.md`, item 1.
- `reviews/2026-10-21T0009Z-source-investigation-reviewer-1.md`, SI1, and its verbatim
  companion.
- `reviews/2026-10-21T0033Z-source-investigation-reviewers-2-4.md`, RV1, and the three
  verbatim answers.
- **PipeWire 1.0.5** `spa/plugins/bluez5/backend-native.c`: `sco_do_connect()` 1440–1451,
  `sco_ready()` 1489–1498, `sco_event()` 1653–1669 (`cache/pipewire-upstream`).
- **bluetooth-next:** `hci_sync.c:5905` `hci_disconnect_sync()`, `hci_sync.c:6058`
  `hci_abort_conn_sync()`, `lib.c:128` (0x16 → `ECONNABORTED`).

**Captures** (raw, git-ignored, real addresses):
- The earbuds' switches, 2026-09-29 02:30:40 to 02:31:45, and the MOMENTUM 4's, 2026-10-01
  00:54 to 00:56.
- Both are in the HCI capture directories and the archive. `EX-060` names the files and the
  commands.

**Source**, as read on bluetooth-next `27731ba09195`:
- `net/bluetooth/hci_conn.c:1892`: `hci_connect_sco()`.
- `include/net/bluetooth/hci_core.h:1285`: `hci_conn_hash_lookup_ba()`.
- `net/bluetooth/hci_conn.c:3253`: `hci_abort_conn()`.
- `net/bluetooth/sco.c`: `sco_connect()` (the `BT_CONNECTED` check at 417), `sco_chan_del()`,
  `sco_conn_del()`, `sco_disconn_cfm()`.
- Ubuntu `7.0.0-38` (`cache/ubuntu-7.0.0-38`): the same lines in `hci_conn.c`, 1771 to 1801.

**Upstream:**
- BlueZ #2562, "SCO: rejected duplicate Enhanced Setup Synchronous Connection …".
- Hitalo Souza, "[v3 0/6] Bluetooth: Fix SCO setup failures after an abandoned setup",
  patchwork series 1181908 (patches 14875449 to 14875454; cover 14157860).
- PipeWire #5506 and #5476 (nearby, not the same).
