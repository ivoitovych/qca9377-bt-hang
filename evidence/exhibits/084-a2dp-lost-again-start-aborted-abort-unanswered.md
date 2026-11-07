# EX-084 — a2dp-lost-again-start-aborted-abort-unanswered

**Claim.** U12 again, 2026-10-31 13:42:16, MOMENTUM 4: bluetoothd sends AVDTP Start (label 8) at 13:42:16.187828 and Abort (label 9) 87.5 ms later, before any answer; the headset accepts the Start (label 8) at 16.444751 and sends nothing more on the signalling channel until 18.962, when bluetoothd sends L2CAP Disconnection Requests for three channels. An mSBC eSCO link to the same headset completes with Success at 16.464811 meanwhile.

**Relevance.** The second occurrence of EX-063's pattern: the Abort that a Release during a pending Acquire produces in BlueZ 5.72 is never answered by this headset, so bluetoothd ends the whole A2DP session. Upstream a14d59725 (BlueZ 5.80) removes the Abort.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/capture-window.sh /root/exp/qca9377-bt-hang/archive/incidents/20261031-momentum-headphones-missing/hci-20261031-131400.btsnoop '2026-10-31 13:42:16' '2026-10-31 13:42:19.1' 'Channel: (65|388) |Synchronous Connect Complete|L2CAP: Disconnection'
```

## Output

Verbatim, 43 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
< ACL Data TX: Handle 14 flags 0x00 dlen 7                                                                            #175448 [hci0] 2026-10-31 13:42:16.187828
      Channel: 388 len 3 [PSM 0 mode Basic (0x00)] {chan 65535}
        80 07 1c                                         ...             
< ACL Data TX: Handle 14 flags 0x00 dlen 7                                                                            #175451 [hci0] 2026-10-31 13:42:16.275333
      Channel: 388 len 3 [PSM 0 mode Basic (0x00)] {chan 65535}
        90 0a 1c                                         ...             
> ACL Data RX: Handle 14 flags 0x02 dlen 6                                                                            #175461 [hci0] 2026-10-31 13:42:16.444751
      Channel: 65 len 2 [PSM 0 mode Basic (0x00)] {chan 65535}
        82 07                                            ..              
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #175465 [hci0] 2026-10-31 13:42:16.464811
        Status: Success (0x00)
        Handle: 17
        Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)
< ACL Data TX: Handle 14 flags 0x00 dlen 12                                                                           #177138 [hci0] 2026-10-31 13:42:18.962038
      L2CAP: Disconnection Request (0x06) ident 10 len 4
        Destination CID: 453
        Source CID: 66
> ACL Data RX: Handle 14 flags 0x02 dlen 12                                                                           #177155 [hci0] 2026-10-31 13:42:18.978698
      L2CAP: Disconnection Response (0x07) ident 10 len 4
        Destination CID: 453
        Source CID: 66
< ACL Data TX: Handle 14 flags 0x00 dlen 12                                                                           #177156 [hci0] 2026-10-31 13:42:18.986875
      L2CAP: Disconnection Request (0x06) ident 11 len 4
        Destination CID: 518
        Source CID: 67
< ACL Data TX: Handle 14 flags 0x00 dlen 12                                                                           #177159 [hci0] 2026-10-31 13:42:18.987112
      L2CAP: Disconnection Request (0x06) ident 12 len 4
        Destination CID: 388
        Source CID: 65
> ACL Data RX: Handle 14 flags 0x02 dlen 12                                                                           #177185 [hci0] 2026-10-31 13:42:19.026762
      L2CAP: Disconnection Response (0x07) ident 11 len 4
        Destination CID: 518
        Source CID: 67
> ACL Data RX: Handle 14 flags 0x02 dlen 12                                                                           #177186 [hci0] 2026-10-31 13:42:19.026813
      L2CAP: Disconnection Response (0x07) ident 12 len 4
        Destination CID: 388
        Source CID: 65
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-31T14:54:31+01:00` |
| kernel | `7.0.0-42-generic` |
| capture boot id | `e672b454` |
| evidence boot ids | none named by the command (it selects by index or not by boot) — see the window above |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
