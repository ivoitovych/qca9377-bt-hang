# CO-27 — A headset known only from its LE advertising cannot be set up (U13)

**State:** investigating. Confirmed in the HCI capture, the log and the source on 2026-10-21;
no reproducer or patch yet.

**Target:** BlueZ (`src/adapter.c`, `src/eir.c`); GNOME Settings / gnome-bluetooth (the silent
failure); possibly a note to Shure.

**Comes from:** `U13` (`docs/issues.md`): the operator clicked the Shure AONIC 50 in GNOME
Settings' Bluetooth panel about a dozen times; each click was a pairing attempt over LE that
the headset refused.

## The finding

1. The AONIC 50 sends connectable LE advertising with **Flags `0x00`** under its public
   address, and refuses LE pairing: `SMP: Pairing Failed, Reason: Pairing not supported (0x05)`.
2. BlueZ learns a device's BR/EDR side from LE advertising only through the Flags, and its
   test `eir_data.flags && !(eir_data.flags & EIR_BREDR_UNSUP)` reads Flags `0x00` as no Flags
   (5.72 `src/adapter.c:7277`; master `:7696`). The device stays LE-only
   (`SupportedTechnologies=LE;`), so `Pair()` picks LE (`src/device.c:3032-3037`,
   `select_conn_bearer()`).
3. GNOME Settings shows nothing for the failed `Pair()`.

`PreferredBearer` (BlueZ 5.80) does not cover it: it exists only for a device known on both
bearers.

## Possible contributions

- **BlueZ patch:** record whether the Flags field was present in `struct eir_data`, and treat a
  present Flags without "BR/EDR Not Supported" as BR/EDR support for a public address. Then
  `select_conn_bearer()` prefers BR/EDR for equal times (`src/device.c:2513-2516`). To weigh:
  LE-only devices that send Flags `0x00` would be marked BR/EDR-capable and could be paged in
  vain. The 2026-07-17 change (Philipp Dunkel, public addresses only) is the precedent for that
  kind of harm.
- **BlueZ, alternative:** when LE pairing is refused as "Pairing not supported" by a device with
  a public address, retry over BR/EDR, or report a specific error.
- **GNOME:** a failed pairing should say so. Read GNOME 46.7 / gnome-bluetooth first, and look
  for an existing report.

## Next

Done: the retry in pairing mode (2026-10-21 06:40:44, it paired over BR/EDR, `log.md`); a search
of BlueZ's GitHub issues (2026-10-28): no report of Flags `0x00`, and one sibling, **BlueZ #2700**
(2026-10-22, open, no reply): a dual-mode headset paired over LE because BlueZ knows only its LE
side. **U18** (`docs/issues.md`, 2026-10-24) is the next step of the same path: once paired over
LE, `Connect` succeeds with only the LE GATT services connected.

1. A reproducer for the BlueZ side: BlueZ's emulator advertising Flags `0x00` with a BR/EDR
   side; today `SupportedTechnologies` stays `LE`. Then one for U18.
2. A patch candidate for each defect (U13: Flags presence; U18: count only non-LE services).
3. Possibly first, a comment on #2700 with our two cases and evidence (no real addresses).
4. The BlueZ mailing list and GNOME's tracker are not searched yet.

**Decides:** sending anything is the operator's decision.
