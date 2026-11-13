# EX-089 — a2dp-lost-third-abort-answered-still-disconnects

**Claim.** U12 again, 2026-11-13: at 14:19:53.445 PipeWire's D-Bus owner requests Acquire of the MOMENTUM 4's A2DP transport; at .482 the request is withdrawn and bluetoothd aborts the setup (a2dp_cancel(), stream OPEN -> ABORTING). This time the headset accepts the Abort at .509 ('ABORT request succeeded'), and bluetoothd still drops A2DP: a2dp-sink goes to disconnected at once and the AVDTP session is closed at .536.

**Relevance.** bluetoothd's half. Unlike 10-19 and 10-31 the Abort is answered, so the disconnect does not wait for the 2 s Abort timeout: in BlueZ 5.72 the Abort itself ends the A2DP session, as upstream a14d59725 describes.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b af3f984071f14b89b609ce65e6cc8799 --since '2026-11-13 14:19:53.4' --until '2026-11-13 14:19:53.6' -o short-iso-precise --no-pager -t bluetoothd --grep 'media_owner_add|media_owner_remove|a2dp_cancel|ABORT request|abort_cfm|stream state change|connection_lost|a2dp-sink state changed'
```

## Output

Verbatim, 10 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-11-13T14:19:53.445579+01:00 n bluetoothd[2844]: profiles/audio/transport.c:media_owner_add() Owner :1.88 Request Acquire
2026-11-13T14:19:53.482221+01:00 n bluetoothd[2844]: profiles/audio/transport.c:media_owner_remove() Owner :1.88 Request Acquire
2026-11-13T14:19:53.482255+01:00 n bluetoothd[2844]: profiles/audio/a2dp.c:a2dp_cancel() aborting setup 0x5c9b5a9b43c0
2026-11-13T14:19:53.482263+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: OPEN -> ABORTING
2026-11-13T14:19:53.509159+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_parse_resp() ABORT request succeeded
2026-11-13T14:19:53.509171+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state change failed: Input/output error
2026-11-13T14:19:53.509181+01:00 n bluetoothd[2844]: profiles/audio/a2dp.c:abort_cfm() Source 0x5c9b5a9a70e0: Abort_Cfm
2026-11-13T14:19:53.509207+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: ABORTING -> IDLE
2026-11-13T14:19:53.509283+01:00 n bluetoothd[2844]: src/service.c:change_state() 0x5c9b5a98f420: device AA:BB:CC:00:00:01 profile a2dp-sink state changed: connected -> disconnected (0)
2026-11-13T14:19:53.536486+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:connection_lost() Disconnected from AA:BB:CC:00:00:01
```

**Evidence window.** `2026-11-13T14:19:53.445579+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:30:28+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
