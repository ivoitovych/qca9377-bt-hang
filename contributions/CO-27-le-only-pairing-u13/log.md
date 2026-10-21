# CO-27 log

## 2026-10-21 06:20 to 06:40 — the live failure, read while it happened
- The operator, live: the AONIC 50 listed as "Not set up"; each click a brief spinner, then
  "Not set up" again; about a dozen clicks.
- Read-only checks only (no `bluetoothctl`, which registers an agent and changes adapter
  state): the bluetoothd debug journal, `busctl get-property` on the device, BlueZ's storage
  files, `scripts/capture-window.sh` on the running capture.
- 13 bonding attempts 06:20:39 to 06:23:10, all `type 1` (LE), all Authentication Failed. The
  capture shows why: the headset's SMP "Pairing not supported (0x05)". Its advertising has
  Flags `0x00`; the MOMENTUM 4's has `0x18`.
- Source read in BlueZ 5.72 and upstream master: the Flags test, `select_conn_bearer()`,
  `PreferredBearer`'s both-bearers condition, the discoverable filter.
- Raw evidence saved to `archive/incidents/20261021-shure-le-pair/` at 06:31 (local only, it
  carries real addresses). The storage `info` file had expired at 06:30:41; its content is
  quoted in `U13`, as read at about 06:25.
