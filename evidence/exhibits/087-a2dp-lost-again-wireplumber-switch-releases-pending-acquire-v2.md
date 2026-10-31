# EX-087 — a2dp-lost-again-wireplumber-switch-releases-pending-acquire-v2

**Claim.** U12 again, 2026-10-31: WirePlumber (0.4.17) starts acquiring the MOMENTUM 4's A2DP transport at 13:42:16.187; 86 ms later, at 16.274, it switches the card from a2dp-sink to headset-head-unit-msbc and releases that transport while the acquire is pending; the hands-free link comes up at 16.478. At 18.964, after bluetoothd lost A2DP, it finds no default profile and keeps headset-head-unit-msbc, the best one left.

**Relevance.** The trigger side of EX-084/EX-085: the switch to the headset profile when an application opens the microphone, by WirePlumber's design, issues the Release that BlueZ 5.72 turns into an AVDTP Abort. Replaces EX-086, whose identifier filter matched nothing.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/user-journal.sh -b e672b4545c844ab88758175b455f8906 --since '2026-10-31 13:42:16' --until '2026-10-31 13:42:19.1' --grep 'Acquiring transport|Setting profile of|Releasing transport|fd10 released|acquire complete|Default profile not found|Found best profile'
```

## Output

Verbatim, 17 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-10-31T13:42:16.187069+01:00 n wireplumber[2811]: Acquiring transport /org/bluez/hci0/dev_AA:BB:CC:00:00:01/fd10
2026-10-31T13:42:16.273676+01:00 n wireplumber[2811]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-31T13:42:16.274791+01:00 n wireplumber[2811]: Releasing transport /org/bluez/hci0/dev_AA:BB:CC:00:00:01/fd10
2026-10-31T13:42:16.276009+01:00 n wireplumber[2811]: Transport /org/bluez/hci0/dev_AA:BB:CC:00:00:01/fd10 released
2026-10-31T13:42:16.477981+01:00 n wireplumber[2811]: transport 0x5fe8bc02fc80: acquire complete, read_mtu=50, write_mtu=50
2026-10-31T13:42:18.964420+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:18.964510+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.001413+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.001487+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.007575+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.007644+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.013081+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.013169+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.018040+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.018124+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.022735+01:00 n wireplumber[2811]: Default profile not found for bluez_card.AA:BB:CC:00:00:01
2026-10-31T13:42:19.022834+01:00 n wireplumber[2811]: Found best profile headset-head-unit-msbc for bluez_card.AA:BB:CC:00:00:01
```

**Evidence window.** `2026-10-31T13:42:16.187069+01:00` — `2026-10-31T13:42:19.001413+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-31T14:55:15+01:00` |
| kernel | `7.0.0-42-generic` |
| capture boot id | `e672b454` |
| evidence boot ids | `e672b454` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
