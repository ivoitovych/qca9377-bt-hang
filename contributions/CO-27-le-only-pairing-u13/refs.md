# CO-27 references

- Issue: `docs/issues.md` U13; STATUS row `U13`.
- Raw evidence (this machine only): `archive/incidents/20261021-shure-le-pair/`, `SHA256SUMS`
  inside; saved by `tmp/incident-20261021-shure/save-raw.sh`.
- Capture: `/var/log/bt-health/trace/bt-20261021-013411.btsnoop` (copied into the archive
  directory), window 2026-10-21 06:20:30 to 06:21:10.
- BlueZ 5.72: `src/device.c:2477-2520` (`select_conn_bearer()`), `:3032-3037` (`Pair()`);
  `src/adapter.c:7134-7178` (`device_is_discoverable()`), `:7277-7281` (the Flags test).
- BlueZ master: `src/adapter.c:7696-7697` (`9965f36c63`, Philipp Dunkel, 2026-07-17; the
  `flags &&` test from `976f793028`, Luiz Augusto von Dentz, 2016-08-10); `src/device.c:389-393`
  (`device_prefer_bearer_str()`).
- `PreferredBearer`: `a22935f9b`, `03240630b`, `f2e7c8f99`, `4d3c721ee` (Luiz Augusto von
  Dentz, 2025-02-26), `f39b3ec12` (2025-05-16, "last-used"); first in 5.80.
- Earlier AONIC 50 use over BR/EDR: `U11` (2026-10-13).
