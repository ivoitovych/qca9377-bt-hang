# EX-090 — a2dp-lost-third-chrome-microphone-switches-profile

**Claim.** U12 again, 2026-11-13: Google Chrome opens a playback stream at 14:19:53.437 and a recording stream at .478; at .481 WirePlumber switches the MOMENTUM 4 from a2dp-sink to headset-head-unit-msbc, while bluetoothd's Acquire of the A2DP transport is pending. When the recording ends, at 14:20:28, WirePlumber logs 'Failed to restore profile'.

**Relevance.** The trigger, as on 10-19 and 10-31: WirePlumber 0.4.17 moves the headset to Handsfree for a recording stream, and its Release lands while A2DP is starting.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/user-journal.sh -b af3f984071f14b89b609ce65e6cc8799 --since '2026-11-13 14:19:53' --until '2026-11-13 14:20:29' --grep 'CREATE_PLAYBACK_STREAM|CREATE_RECORD_STREAM|Setting profile of|Failed to restore profile'
```

## Output

Verbatim, 10 line(s), exit status 0.

```
2026-11-13T14:19:53.437510+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-11-13T14:19:53.443284+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:109 missing:8192 lat:10666
2026-11-13T14:19:53.478789+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome input] CREATE_RECORD_STREAM tag:172 corked:1 source-name:(null) source-index:4294967295
2026-11-13T14:19:53.481554+01:00 n wireplumber[2935]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-11-13T14:19:53.499876+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome input] reply CREATE_RECORD_STREAM tag:172 index:114 latency:10000
2026-11-13T14:19:53.505705+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-11-13T14:19:53.519245+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:129 missing:8192 lat:10666
2026-11-13T14:20:26.303983+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] CREATE_PLAYBACK_STREAM tag:2 corked:1 sink-name:(null) sink-index:4294967295
2026-11-13T14:20:26.309588+01:00 n pipewire-pulse[2937]: mod.protocol-pulse: [Google Chrome] reply CREATE_PLAYBACK_STREAM tag:2 index:133 missing:8192 lat:10666
2026-11-13T14:20:28.201542+01:00 n wireplumber[2935]: Failed to restore profile
```

**Evidence window.** `2026-11-13T14:19:53.437510+01:00` — `2026-11-13T14:20:28.201542+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:30:35+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
