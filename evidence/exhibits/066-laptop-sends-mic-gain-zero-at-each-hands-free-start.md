# EX-066 — laptop-sends-mic-gain-zero-at-each-hands-free-start

**Claim.** On 2026-10-23 every hands-free start for the MOMENTUM 4 sent it +VGM: 0. WirePlumber switched it from a2dp-sink to headset-head-unit-msbc when dictation started (02:26:18, 02:32:03, 02:35:33, 02:57:30) and back when it ended; about 230 ms after each switch the eSCO link came up and the laptop sent +VGS: 9 and +VGM: 0, again 1.5 s later. The operator's manual switch at about 02:58 did the same at 02:58:22; dictation at 02:58:49 found the input route already there and sent nothing. The operator heard the headset say 'mute on' at each such start and 'mute off' at each return to A2DP. WirePlumber's saved microphone volume for the MOMENTUM is 0.0.

**Relevance.** The headset's own AT+VGM=00 (EX-065) becomes the saved microphone volume, and PipeWire sends it back at every hands-free start, which the MOMENTUM announces as mute. The trigger is the hands-free start, not dictation itself: dictation only causes it through U14's automatic switch.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ grep -a -E '2026-10-23T0(2:2|2:3|2:5|3:0)' /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/journal-user-profile-switches.txt; grep -a -h -E 'Synchronous Connect Complete|VGM|VGS' /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/capture-gain-022237.txt /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/capture-gain-025521.txt; grep -a -E 'hf-input:channelVolumes' /root/exp/qca9377-bt-hang/archive/incidents/20261023-momentum-mic-gain-zero/wireplumber-state-default-routes.txt
```

## Output

Verbatim, 49 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
2026-10-23T02:26:18.311024+02:00 n wireplumber[2926]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-23T02:27:11.504002+02:00 n wireplumber[2926]: Setting saved headset profile to: headset-head-unit-msbc
2026-10-23T02:27:11.504253+02:00 n wireplumber[2926]: Restoring profile of 'MOMENTUM 4' from: headset-head-unit-msbc to: a2dp-sink
2026-10-23T02:32:03.456653+02:00 n wireplumber[2926]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-23T02:32:54.559364+02:00 n wireplumber[2926]: Setting saved headset profile to: headset-head-unit-msbc
2026-10-23T02:32:54.559577+02:00 n wireplumber[2926]: Restoring profile of 'MOMENTUM 4' from: headset-head-unit-msbc to: a2dp-sink
2026-10-23T02:35:33.035057+02:00 n wireplumber[2926]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-23T02:37:04.377980+02:00 n wireplumber[2926]: Setting saved headset profile to: headset-head-unit-msbc
2026-10-23T02:37:04.378108+02:00 n wireplumber[2926]: Restoring profile of 'MOMENTUM 4' from: headset-head-unit-msbc to: a2dp-sink
2026-10-23T02:57:30.440030+02:00 n wireplumber[2926]: Setting profile of 'MOMENTUM 4' from: a2dp-sink to: headset-head-unit-msbc
2026-10-23T02:57:38.321931+02:00 n wireplumber[2926]: Setting saved headset profile to: headset-head-unit-msbc
2026-10-23T02:57:38.322203+02:00 n wireplumber[2926]: Restoring profile of 'MOMENTUM 4' from: headset-head-unit-msbc to: a2dp-sink
2026-10-23T02:58:49.786219+02:00 n wireplumber[2926]: Current profile has input route, not switching
2026-10-23T03:01:17.800397+02:00 n wireplumber[2926]: Setting saved headset profile to: headset-head-unit-msbc
2026-10-23T03:01:17.800663+02:00 n wireplumber[2926]: Restoring profile of 'MOMENTUM 4' from: headset-head-unit-msbc to: headset-head-unit-msbc
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #33398 [hci0] 2026-10-23 02:26:18.545060
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #113019 [hci0] 2026-10-23 02:32:03.757576
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #171001 [hci0] 2026-10-23 02:35:33.212441
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #19504 [hci0] 2026-10-23 02:57:30.666024
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #31267 [hci0] 2026-10-23 02:58:22.338180
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
        69 ef 17 0d 0a 2b 56 47 53 3a 20 39 0d 0a 3e     i....+VGS: 9..> 
        69 ef 17 0d 0a 2b 56 47 4d 3a 20 30 0d 0a 3e     i....+VGM: 0..> 
bluez_card.AA:BB:CC:00:00:01:input:headset-hf-input:channelVolumes=0.65911573171616;
bluez_card.AA:BB:CC:00:00:02:input:headphone-hf-input:channelVolumes=1.0;
bluez_card.AA:BB:CC:00:00:03:input:headset-hf-input:channelVolumes=1.0;
bluez_card.AA:BB:CC:00:00:04:input:headset-hf-input:channelVolumes=0.21600000560284;
bluez_card.AA:BB:CC:00:00:05:input:headset-hf-input:channelVolumes=1.0;
bluez_card.AA:BB:CC:00:00:06:input:headset-hf-input:channelVolumes=1.0;
bluez_card.AA:BB:CC:00:00:07:input:bluetooth-hf-input:channelVolumes=0.0;
bluez_card.AA:BB:CC:00:00:07:input:headset-hf-input:channelVolumes=0.0;
bluez_card.AA:BB:CC:00:00:08:input:headset-hf-input:channelVolumes=1.0;
```

**Evidence window.** `2026-10-23T02:26:18.311024+02:00` — `2026-10-23T03:01:17.800397+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-23T03:11:00+02:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `d479d374` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
