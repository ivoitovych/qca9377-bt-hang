# EX-091 — a2dp-lost-third-capture-abort-before-start

**Claim.** U12 again, 2026-11-13, over the air: no AVDTP Start is sent; the AVDTP Abort goes out at 14:19:53.482304 and the headset accepts it at .509065 (27 ms). bluetoothd then disconnects the A2DP L2CAP channels (.509, .536). An mSBC eSCO link, set up meanwhile, completes with Success at .700386.

**Relevance.** The radio side: the headset is not silent this time and the controller is healthy; the A2DP loss is bluetoothd's own decision after the Abort.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/capture-window.sh /var/log/bt-health/trace/bt-20261113-112428.btsnoop '2026-11-13 14:19:53.400' '2026-11-13 14:19:56.000' 'AVDTP|L2CAP: Disc|Synchronous Connect Complete|Status:'
```

## Output

Verbatim, 52 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
< ACL Data TX: Handle 6 flags 0x00 dlen 7                                                                                #800 [hci0] 2026-11-13 14:19:53.482304
      Channel: 388 len 3 [PSM 25 mode Basic (0x00)] {chan 2}
      AVDTP: Abort (0x0a) Command (0x00) type 0x00 label 0 nosp 0
        ACP SEID: 7
> HCI Event: Command Status (0x0f) plen 4                                                                                #802 [hci0] 2026-11-13 14:19:53.485385
      Exit Sniff Mode (0x02|0x0004) ncmd 1
        Status: Success (0x00)
> HCI Event: Mode Change (0x14) plen 6                                                                                   #804 [hci0] 2026-11-13 14:19:53.503378
        Status: Success (0x00)
        Handle: 6 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Mode: Active (0x00)
        Interval: 0.000 msec (0x0000)
> ACL Data RX: Handle 6 flags 0x02 dlen 6                                                                                #807 [hci0] 2026-11-13 14:19:53.509065
      Channel: 65 len 2 [PSM 25 mode Basic (0x00)] {chan 2}
      AVDTP: Abort (0x0a) Response Accept (0x02) type 0x00 label 0 nosp 0
< ACL Data TX: Handle 6 flags 0x00 dlen 12                                                                               #808 [hci0] 2026-11-13 14:19:53.509395
      L2CAP: Disconnection Request (0x06) ident 10 len 4
        Destination CID: 453
        Source CID: 66
> ACL Data RX: Handle 6 flags 0x02 dlen 12                                                                               #810 [hci0] 2026-11-13 14:19:53.511064
      L2CAP: Disconnection Request (0x06) ident 17 len 4
        Destination CID: 67
        Source CID: 518
< ACL Data TX: Handle 6 flags 0x00 dlen 12                                                                               #811 [hci0] 2026-11-13 14:19:53.511083
      L2CAP: Disconnection Response (0x07) ident 17 len 4
        Destination CID: 67
        Source CID: 518
> HCI Event: Command Status (0x0f) plen 4                                                                                #812 [hci0] 2026-11-13 14:19:53.512373
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
< ACL Data TX: Handle 6 flags 0x00 dlen 12                                                                               #817 [hci0] 2026-11-13 14:19:53.536671
      L2CAP: Disconnection Request (0x06) ident 11 len 4
        Destination CID: 388
        Source CID: 65
> ACL Data RX: Handle 6 flags 0x02 dlen 12                                                                               #819 [hci0] 2026-11-13 14:19:53.542063
      L2CAP: Disconnection Response (0x07) ident 10 len 4
        Destination CID: 453
        Source CID: 66
> ACL Data RX: Handle 6 flags 0x02 dlen 12                                                                               #820 [hci0] 2026-11-13 14:19:53.576062
      L2CAP: Disconnection Response (0x07) ident 11 len 4
        Destination CID: 388
        Source CID: 65
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                                 #821 [hci0] 2026-11-13 14:19:53.700386
        Status: Success (0x00)
        Handle: 8
        Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:30:38+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
