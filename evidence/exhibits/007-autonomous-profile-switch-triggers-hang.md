# EX-007 — autonomous-profile-switch-triggers-hang

**Claim.** The hang requires NO operator action. It is triggered by audio playback STOPPING: when the A2DP stream goes idle, PipeWire switches the device to the HFP profile 36 ms later, BlueZ issues HCI_Setup_Synchronous_Connection, and the controller never answers it.

**Relevance.** This explains why the failure appeared random and why it resisted deliberate reproduction — the operator kept it alive by interacting with it, and it died 77 s after they stopped, when a video ended. It also unifies every previously unexplained symptom: the hands-free/mono fallback, the recurring 'setting interface failed' (btusb changing the USB alternate setting to allocate isochronous bandwidth for SCO), and the AVDTP-teardown early-warning signature. It yields a minimal reproducer: play audio to a headset, stop it, wait.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b 0 --since '2026-08-12 04:59:00' --until '2026-08-12 05:00:20' --no-pager -o short-iso-precise -u bluetooth | grep -E 'media_player_set_status|transport_set_state|sink_set_state|avdtp_sep_set_state' | tail -6; echo; echo '--- kernel side ---'; journalctl -k -b 0 --since '2026-08-12 05:00:16' --until '2026-08-12 05:00:19' --no-pager -o short-iso-precise | grep -iE 'opcode 0x0428|command tx timeout'
```

## Output

Verbatim, 9 line(s), exit status 0.

```
2026-08-12T04:59:01.460742+02:00 n bluetoothd[8257]: profiles/audio/player.c:media_player_set_status() stopped
2026-08-12T05:00:16.521027+02:00 n bluetoothd[8257]: profiles/audio/transport.c:transport_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01/sep7/fd8: TRANSPORT_STATE_ACTIVE -> TRANSPORT_STATE_SUSPENDING
2026-08-12T05:00:16.559856+02:00 n bluetoothd[8257]: profiles/audio/avdtp.c:avdtp_sep_set_state() stream state changed: STREAMING -> OPEN
2026-08-12T05:00:16.559870+02:00 n bluetoothd[8257]: profiles/audio/sink.c:sink_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01: SINK_STATE_PLAYING -> SINK_STATE_CONNECTED
2026-08-12T05:00:16.559980+02:00 n bluetoothd[8257]: profiles/audio/transport.c:transport_set_state() State changed /org/bluez/hci0/dev_AA:BB:CC:00:00:01/sep7/fd8: TRANSPORT_STATE_SUSPENDING -> TRANSPORT_STATE_IDLE

--- kernel side ---
2026-08-12T05:00:16.595818+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-12T05:00:18.764738+02:00 n kernel: Bluetooth: hci0: command tx timeout
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T05:24:36+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `c1315c25` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
