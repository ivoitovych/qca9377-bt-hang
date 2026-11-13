# EX-096 — a2dp-restored-by-connectprofile

**Claim.** U12's state is undone without a reconnect: at 15:13:00.267 on 2026-11-13 a D-Bus ConnectProfile for the MOMENTUM 4's A2DP sink (0000110b) makes bluetoothd open AVDTP signalling (.345) and transport (.485); a2dp-sink is connected at .485, the stream STREAMING at .543 (Chrome was playing), and AVRCP follows (.563).

**Relevance.** Shows the controller, the link and the headset were fine for 53 minutes: only bluetoothd's A2DP session was gone, and nothing in the stack tried to bring it back.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b af3f984071f14b89b609ce65e6cc8799 -t bluetoothd --since '2026-11-13 15:13:00' --until '2026-11-13 15:13:01' --no-pager -o short-iso-precise --grep 'connect_profiles|avdtp_connect_cb|stream state changed|a2dp-sink state changed|device_profile_connected|avrcp-controller state changed'
```

## Output

Verbatim, 14 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-11-13T15:13:00.267589+01:00 n bluetoothd[2844]: src/device.c:connect_profiles() /org/bluez/hci0/dev_AA:BB:CC:00:00:01 <UUID-01>, client :1.150
2026-11-13T15:13:00.267701+01:00 n bluetoothd[2844]: src/service.c:change_state() 0x5c9b5a98f420: device AA:BB:CC:00:00:01 profile a2dp-sink state changed: disconnected -> connecting (0)
2026-11-13T15:13:00.345224+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_connect_cb() AVDTP: connected signaling channel to AA:BB:CC:00:00:01
2026-11-13T15:13:00.345241+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_connect_cb() AVDTP imtu=672, omtu=895
2026-11-13T15:13:00.396234+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: IDLE -> CONFIGURED
2026-11-13T15:13:00.485211+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_connect_cb() AVDTP: connected transport channel to AA:BB:CC:00:00:01
2026-11-13T15:13:00.485317+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: CONFIGURED -> OPEN
2026-11-13T15:13:00.485352+01:00 n bluetoothd[2844]: src/service.c:change_state() 0x5c9b5a98f420: device AA:BB:CC:00:00:01 profile a2dp-sink state changed: connecting -> connected (0)
2026-11-13T15:13:00.485370+01:00 n bluetoothd[2844]: src/device.c:device_profile_connected() a2dp-sink Success (0)
2026-11-13T15:13:00.485386+01:00 n bluetoothd[2844]: src/device.c:device_profile_connected() returning response to :1.150
2026-11-13T15:13:00.485624+01:00 n bluetoothd[2844]: src/service.c:change_state() 0x5c9b5a98f320: device AA:BB:CC:00:00:01 profile avrcp-controller state changed: disconnected -> connecting (0)
2026-11-13T15:13:00.543511+01:00 n bluetoothd[2844]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: OPEN -> STREAMING
2026-11-13T15:13:00.563731+01:00 n bluetoothd[2844]: src/service.c:change_state() 0x5c9b5a98f320: device AA:BB:CC:00:00:01 profile avrcp-controller state changed: connecting -> connected (0)
2026-11-13T15:13:00.563751+01:00 n bluetoothd[2844]: src/device.c:device_profile_connected() avrcp-controller Success (0)
```

**Evidence window.** `2026-11-13T15:13:00.267589+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T15:13:23+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
