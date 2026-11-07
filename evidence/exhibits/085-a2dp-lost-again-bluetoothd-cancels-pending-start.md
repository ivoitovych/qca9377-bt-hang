# EX-085 — a2dp-lost-again-bluetoothd-cancels-pending-start

**Claim.** U12 again, 2026-10-31: at 13:42:16.187 PipeWire's D-Bus owner requests Acquire of the MOMENTUM 4's A2DP transport; at 16.275 the same owner's request is withdrawn and bluetoothd cancels the setup ('Start: Operation canceled (125)', a2dp_cancel() aborting setup); at 16.444 it drops the headset's late answer ('Transaction label doesn't match'); at 18.961 the Abort times out ('Abort: Connection timed out (110)'), the A2DP connection is lost and a2dp-sink goes to disconnected.

**Relevance.** bluetoothd's half of EX-084: in BlueZ 5.72 a Release during a pending Acquire becomes an AVDTP Abort, and an unanswered Abort ends the A2DP session.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b e672b4545c844ab88758175b455f8906 --since '2026-10-31 13:42:16' --until '2026-10-31 13:42:19.1' -o short-iso-precise --no-pager -t bluetoothd --grep 'media_owner_add|media_owner_remove|a2dp_cancel|cancel_request|Transaction label|PAUSE|connection_lost|a2dp-sink state changed'
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
2026-10-31T13:42:16.187732+01:00 n bluetoothd[2752]: profiles/audio/transport.c:media_owner_add() Owner :1.81 Request Acquire
2026-10-31T13:42:16.275122+01:00 n bluetoothd[2752]: profiles/audio/transport.c:media_owner_remove() Owner :1.81 Request Acquire
2026-10-31T13:42:16.275182+01:00 n bluetoothd[2752]: profiles/audio/a2dp.c:a2dp_cancel() aborting setup 0x59c4eeb6c620
2026-10-31T13:42:16.275212+01:00 n bluetoothd[2752]: profiles/audio/avdtp.c:cancel_request() Start: Operation canceled (125)
2026-10-31T13:42:16.444847+01:00 n bluetoothd[2752]: profiles/audio/avdtp.c:session_cb() Transaction label doesn't match
2026-10-31T13:42:16.447121+01:00 n bluetoothd[2752]: profiles/audio/avctp.c:handle_panel_passthrough() AV/C: PAUSE pressed
2026-10-31T13:42:16.468909+01:00 n bluetoothd[2752]: profiles/audio/avctp.c:handle_panel_passthrough() AV/C: PAUSE released
2026-10-31T13:42:18.961735+01:00 n bluetoothd[2752]: profiles/audio/avdtp.c:cancel_request() Abort: Connection timed out (110)
2026-10-31T13:42:18.961772+01:00 n bluetoothd[2752]: profiles/audio/avdtp.c:connection_lost() Disconnected from AA:BB:CC:00:00:01
2026-10-31T13:42:18.961899+01:00 n bluetoothd[2752]: src/service.c:change_state() 0x59c4eeb3c4e0: device AA:BB:CC:00:00:01 profile a2dp-sink state changed: connected -> disconnected (0)
```

**Evidence window.** `2026-10-31T13:42:16.187732+01:00` — `2026-10-31T13:42:18.961735+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-31T14:54:41+01:00` |
| kernel | `7.0.0-42-generic` |
| capture boot id | `e672b454` |
| evidence boot ids | `e672b454` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
