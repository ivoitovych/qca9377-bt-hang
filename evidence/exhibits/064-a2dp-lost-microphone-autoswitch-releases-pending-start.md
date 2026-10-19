# EX-064 — a2dp-lost-microphone-autoswitch-releases-pending-start

**Claim.** The A2DP loss of 2026-10-19 follows one chain in the desktop's own logs. At 19:33:58.577 Google Chrome opens a playback stream, and at .636 bluetoothd resumes the MOMENTUM 4's A2DP transport for it. At .674 Chrome opens a microphone stream. At .676 WirePlumber switches the MOMENTUM 4 from a2dp-sink to headset-head-unit-msbc, and at .678 releases the A2DP transport while the resume is pending. bluetoothd answers with a2dp_cancel, aborting the setup and cancelling the Start. At .831 the headset's Start answer arrives and is dropped as a label mismatch. At 19:34:00.963 the Abort times out and bluetoothd disconnects A2DP. At 19:34:07.109, with the microphone stream gone, WirePlumber fails to restore the profile, so only Handsfree remains.

**Relevance.** This is the decision half of U12. WirePlumber 0.4.17 switching to the headset profile when an application opens a microphone is by design; the A2DP session is lost because a Release reaching bluetoothd 5.72 during a pending Acquire is turned into an AVDTP Abort. Upstream BlueZ a14d59725, first released in 5.80, makes bluetoothd wait out the Start and suspend instead. Lines from different journal files are in the order journalctl merged them.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -D /root/exp/qca9377-bt-hang/archive/incidents/20261019-a2dp-lost/journal/files --since '2026-10-19 19:33:58.55' --until '2026-10-19 19:34:07.2' --no-pager -o short-iso-precise --grep 'CREATE_PLAYBACK_STREAM|media_transport_resume|Google Chrome input-99. creating|Setting profile of|transport 0x.*: Release|a2dp_cancel|cancel_request|Transaction label|connection_lost|a2dp-sink state changed|Failed to restore profile'
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
2026-10-19T19:33:58.576934+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-10-19T19:33:58.636364+02:00 n bluetoothd[45092]: profiles/audio/transport.c:media_transport_resume() Transport /org/bluez/hci0/dev_AA:BB:CC:00:00:01/fd39 Owner :1.84
2026-10-19T19:33:58.594962+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:6305 missing:8192 lat:10666
2026-10-19T19:33:58.674378+02:00 n pipewire[2875]: pw.node: (Google Chrome input-99) creating -> suspended
2026-10-19T19:33:58.678381+02:00 n bluetoothd[45092]: profiles/audio/a2dp.c:a2dp_cancel() aborting setup 0x616e1900e900
2026-10-19T19:33:58.678650+02:00 n bluetoothd[45092]: profiles/audio/avdtp.c:cancel_request() Start: Operation canceled (125)
2026-10-19T19:33:58.676126+02:00 n wireplumber[2880]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-19T19:33:58.678066+02:00 n wireplumber[2880]: transport 0x63801a981c90: Release /org/bluez/hci0/dev_AA:BB:CC:00:00:01/fd39
2026-10-19T19:33:58.751961+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-10-19T19:33:58.761663+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:6324 missing:8192 lat:10666
2026-10-19T19:33:58.831166+02:00 n bluetoothd[45092]: profiles/audio/avdtp.c:session_cb() Transaction label doesn't match
2026-10-19T19:34:00.963112+02:00 n bluetoothd[45092]: profiles/audio/avdtp.c:cancel_request() Abort: Connection timed out (110)
2026-10-19T19:34:00.963149+02:00 n bluetoothd[45092]: profiles/audio/avdtp.c:connection_lost() Disconnected from AA:BB:CC:00:00:01
2026-10-19T19:34:00.963267+02:00 n bluetoothd[45092]: src/service.c:change_state() 0x616e18fc1b70: device AA:BB:CC:00:00:01 profile a2dp-sink state changed: connected -> disconnected (0)
2026-10-19T19:34:06.111436+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-10-19T19:34:06.118998+02:00 n pipewire-pulse[2881]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:6329 missing:8192 lat:10666
2026-10-19T19:34:07.108582+02:00 n wireplumber[2880]: Failed to restore profile
```

**Evidence window.** `2026-10-19T19:33:58.576934+02:00` — `2026-10-19T19:34:07.108582+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-19T20:38:12+02:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `17cfdfc4` |
| evidence boot ids | `17cfdfc4` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
