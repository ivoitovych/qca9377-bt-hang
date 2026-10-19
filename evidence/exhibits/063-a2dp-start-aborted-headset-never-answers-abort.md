# EX-063 — a2dp-start-aborted-headset-never-answers-abort

**Claim.** When the A2DP transport is released while its AVDTP Start is pending, bluetoothd sends AVDTP Abort 42 ms after the Start, before any answer. The MOMENTUM 4 accepts the Start 195 ms after it was sent and never answers the Abort. 2.285 s after the Abort bluetoothd sends L2CAP Disconnection Requests for three channels, the A2DP signalling channel 388 that carried the Start and the Abort among them. In the same seconds an mSBC eSCO link to the same headset is set up and completes with Success, so the controller answers throughout. 2026-10-19 19:33:58 to 19:34:01, local time.

**Relevance.** This is the over-the-air half of U12. Upstream BlueZ a14d59725, first released in 5.80, removes the Abort: a Release during a pending Acquire then waits for the Start to complete and suspends the stream. The running bluetoothd is a local 5.72 build without it. Because this headset never answers the Abort, the whole A2DP session ends rather than only the stream.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/capture-window.sh /root/exp/qca9377-bt-hang/archive/incidents/20261019-a2dp-lost/trace/bt-20261019-180021.btsnoop '2026-10-19 19:33:58' '2026-10-19 19:34:02' 'AVDTP|Synchronous|L2CAP: Disconnection'
```

## Output

Verbatim, 64 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
< ACL Data TX: Handle 5 flags 0x00 dlen 7                                                                             #168585 [hci0] 2026-10-19 19:33:58.636434
      Channel: 388 len 3 [PSM 25 mode Basic (0x00)] {chan 2}
      AVDTP: Start (0x07) Command (0x00) type 0x00 label 12 nosp 0
        ACP SEID: 7
< ACL Data TX: Handle 5 flags 0x00 dlen 7                                                                             #168588 [hci0] 2026-10-19 19:33:58.678676
      Channel: 388 len 3 [PSM 25 mode Basic (0x00)] {chan 2}
      AVDTP: Abort (0x0a) Command (0x00) type 0x00 label 13 nosp 0
        ACP SEID: 7
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #168593 [hci0] 2026-10-19 19:33:58.815317
        Handle: 5 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Transmit bandwidth: 8000
        Receive bandwidth: 8000
        Max latency: 13
        Setting: 0x0003
          Input Coding: Linear
          Input Data Format: 1's complement
          Input Sample Size: 8-bit
          # of bits padding at MSB: 0
          Air Coding Format: Transparent Data
        Retransmission effort: Optimize for link quality (0x02)
        Packet type: 0x0380
          3-EV3 may not be used
          2-EV5 may not be used
          3-EV5 may not be used
> HCI Event: Command Status (0x0f) plen 4                                                                             #168595 [hci0] 2026-10-19 19:33:58.819282
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> ACL Data RX: Handle 5 flags 0x02 dlen 6                                                                             #168601 [hci0] 2026-10-19 19:33:58.831050
      Channel: 65 len 2 [PSM 25 mode Basic (0x00)] {chan 2}
      AVDTP: Start (0x07) Response Accept (0x02) type 0x00 label 12 nosp 0
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #168608 [hci0] 2026-10-19 19:33:59.028298
        Status: Success (0x00)
        Handle: 7
        Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)
< ACL Data TX: Handle 5 flags 0x00 dlen 12                                                                            #169905 [hci0] 2026-10-19 19:34:00.963877
      L2CAP: Disconnection Request (0x06) ident 10 len 4
        Destination CID: 453
        Source CID: 66
> ACL Data RX: Handle 5 flags 0x02 dlen 12                                                                            #169912 [hci0] 2026-10-19 19:34:00.974059
      L2CAP: Disconnection Response (0x07) ident 10 len 4
        Destination CID: 453
        Source CID: 66
< ACL Data TX: Handle 5 flags 0x00 dlen 12                                                                            #169916 [hci0] 2026-10-19 19:34:00.980199
      L2CAP: Disconnection Request (0x06) ident 11 len 4
        Destination CID: 518
        Source CID: 67
< ACL Data TX: Handle 5 flags 0x00 dlen 12                                                                            #169917 [hci0] 2026-10-19 19:34:00.980375
      L2CAP: Disconnection Request (0x06) ident 12 len 4
        Destination CID: 388
        Source CID: 65
> ACL Data RX: Handle 5 flags 0x02 dlen 12                                                                            #169934 [hci0] 2026-10-19 19:34:00.998048
      L2CAP: Disconnection Response (0x07) ident 11 len 4
        Destination CID: 518
        Source CID: 67
> ACL Data RX: Handle 5 flags 0x02 dlen 12                                                                            #169938 [hci0] 2026-10-19 19:34:01.002045
      L2CAP: Disconnection Response (0x07) ident 12 len 4
        Destination CID: 388
        Source CID: 65
```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-19T20:38:01+02:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `17cfdfc4` |
| evidence boot ids | `17cfdfc4` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
