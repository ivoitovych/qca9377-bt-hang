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

## 2026-10-21 06:37 to 06:41 — pairing mode works
- 06:37:49 the headset connected over BR/EDR by itself and dropped after 4 s (reason 3).
- 06:38:03 to 06:39:10 three more clicks, still LE, still refused: the operator saw the entry
  listed before the headset announced its pairing mode.
- 06:40:14 bluetoothd learnt the BR/EDR services; 06:40:44 the click paired over BR/EDR (link
  key type 4, status 0); HFP, A2DP and AVRCP connected. So the classic side works once an
  inquiry finds it; the defect stays as described (LE-only knowledge leads to LE pairing).
- What came next is `U14` (WirePlumber), not this dossier.

## 2026-10-21 — two details from the operator's account, added afterwards
- **[operator]** Before these attempts the operator turned Bluetooth off on a phone that had
  been connected to the headset. While not in pairing mode the headset was listed and each click
  failed; after its no-connection power-off timeout it left the list, and came back when powered
  on.
- **[operator, log] An adapter power cycle did not help:** bluetoothd `adapter_set_power_state()
  off-blocked` at 06:38:35.948, `off` / `off-enabling` at 06:38:50.180, `on` at 06:38:50.501
  (the controller came back normally); the next click, 06:39:09, again paired over LE and was
  refused (`type 1 status 0x5`).

## 2026-10-28 — freshness walkthrough; a sibling report upstream
- **Upstream unchanged for this:** BlueZ master `b0bf49270d44`; since 10-15 only `b25019027`
  ("bearer: Promote to stable", the Bearer interfaces out of experimental) and `aa3d6c761`
  (rfkill) touch `src/adapter.c`/`src/device.c`/`src/bearer.c`. The Flags test and
  `select_conn_bearer()` are as read on 10-21; `dev_connect()`'s check (U18) as on 10-24.
- **Duplicate search (step 3, first done today):** `gh search issues --repo bluez/bluez` for
  headset/LE, BR/EDR pairing and bearer. No report of Flags `0x00` or of U18's "Connected over LE
  with no audio profile" as such. **The closest is #2700**, open since 2026-10-22, no reply yet:
  a dual-mode audio headset (CMF Neckband Pro; BlueZ 5.85, Ubuntu's 7.0.0-38) is
  BR/EDR-connectable but not BR/EDR-discoverable, so GNOME Settings and `bluetoothctl` pair it over
  LE. The pairing succeeds with a derived BR/EDR key that the headset does not keep, and every
  later classic connect fails with `br-connection-key-missing`. The reporter has no HCI trace and
  asks: (1) should BlueZ prefer BR/EDR pairing for a peer advertising classic audio UUIDs or an
  Audio/Video class; (2) should there be a supported way to pair over a chosen transport. Their
  workaround makes the BR/EDR object exist first (`sdptool browse` the public address), then
  pairs it.
- **How U13 relates:** the same root, "known only from LE, so paired over LE", reached by a
  different peer. Ours advertises Flags `0x00` from its public address and refuses LE pairing
  ("Pairing not supported"), so nothing is bonded and the panel shows nothing. U18 is the next
  step: once paired over LE in pairing mode, `Connect` reports success with only the LE GATT
  services connected. We have what #2700 lacks: HCI captures, the bluetoothd debug journal and
  the source lines (`docs/issues.md` U13, U18).
- **Readiness:** no reproducer and no patch. Missing: the emulator reproducer (Flags `0x00`
  with a BR/EDR side), a patch candidate for each defect, and the operator's decision. A
  comment on #2700 with our two cases is a cheaper first contribution. Its text would be the
  operator's decision, and it must not give real addresses (the pseudonym table).