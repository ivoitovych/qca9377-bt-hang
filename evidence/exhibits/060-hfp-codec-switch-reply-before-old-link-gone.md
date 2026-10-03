# EX-060 — hfp-codec-switch-reply-before-old-link-gone

**Claim.** In an HFP codec switch made while a SCO link is up, the new link is set up only when the old link's Disconnection Complete event has arrived before the headset's AT+BCS= reply: on the Lenovo earbuds the reply came 16 and 30 ms after the Disconnect and the event 177 and 205 ms after it, and no Setup Synchronous Connection followed either switch (2026-09-29 02:30:44 and 02:31:12); on the MOMENTUM 4 the event came 39 and 46 ms after the Disconnect and the reply 67 and 75 ms after it, and Setup Synchronous Connection followed 24 and 26 ms after the OK (2026-10-01 00:54:45 and 00:55:27).

**Relevance.** The AG's OK goes out within a millisecond of the reply and the first node acquire issues the SCO connect about 25 ms later, so on the earbuds that connect is issued while the previous link to the same peer is still being torn down, and nothing retries once the teardown completes; on the MOMENTUM the old link is already gone when the connect is issued. The difference is the peer's timing, not PipeWire's path, which is the same in all four.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/sco-switch-windows.sh /var/log/bt-health/capture/hci-20260928-185802.btsnoop '2026-09-29 02:30:44' '2026-09-29 02:30:48' /var/log/bt-health/capture/hci-20260928-185802.btsnoop '2026-09-29 02:31:11' '2026-09-29 02:31:16' /var/log/bt-health/capture/hci-20261001-003632.btsnoop '2026-10-01 00:54:44' '2026-10-01 00:54:48' /var/log/bt-health/capture/hci-20261001-003632.btsnoop '2026-10-01 00:55:26' '2026-10-01 00:55:30'
```

## Output

Verbatim, 138 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
== hci-20260928-185802.btsnoop  2026-09-29 02:30:44 .. 2026-09-29 02:30:48
< ACL Data TX:... flags 0x00 dlen 19  #277897 [hci0] 2026-09-29 02:30:44.995667
      Channel: 67 len 15 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
> HCI Event: Command.. (0x0f) plen 4  #277903 [hci0] 2026-09-29 02:30:44.997869
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> ACL Data RX:... flags 0x02 dlen 18  #277909 [hci0] 2026-09-29 02:30:45.012111
      Channel: 65 len 14 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX:... flags 0x00 dlen 14  #277910 [hci0] 2026-09-29 02:30:45.012180
      Channel: 67 len 10 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Disconn.. (0x05) plen 4  #278048 [hci0] 2026-09-29 02:30:45.172855
        Status: Success (0x00)
        Handle: 19 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Connection Terminated By Local Host (0x16)

== hci-20260928-185802.btsnoop  2026-09-29 02:31:11 .. 2026-09-29 02:31:16
< ACL Data TX:... flags 0x00 dlen 19  #286331 [hci0] 2026-09-29 02:31:12.238341
      Channel: 67 len 15 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
> HCI Event: Command.. (0x0f) plen 4  #286333 [hci0] 2026-09-29 02:31:12.241201
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> ACL Data RX:... flags 0x02 dlen 18  #286346 [hci0] 2026-09-29 02:31:12.268108
      Channel: 65 len 14 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX:... flags 0x00 dlen 14  #286347 [hci0] 2026-09-29 02:31:12.268206
      Channel: 67 len 10 [PSM 3 mode Basic (0x00)] {chan 3}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Disconn.. (0x05) plen 4  #286501 [hci0] 2026-09-29 02:31:12.443189
        Status: Success (0x00)
        Handle: 20 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Connection Terminated By Local Host (0x16)

== hci-20261001-003632.btsnoop  2026-10-01 00:54:44 .. 2026-10-01 00:54:48
< ACL Data TX: H.. flags 0x00 dlen 19  #80884 [hci0] 2026-10-01 00:54:45.330603
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
> HCI Event: Command... (0x0f) plen 4  #80888 [hci0] 2026-10-01 00:54:45.336107
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconne.. (0x05) plen 4  #80901 [hci0] 2026-10-01 00:54:45.369106
        Status: Success (0x00)
        Handle: 3 Address: AA:BB:CC:00:00:02 (Sonova Consumer Hearing GmbH)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: H.. flags 0x02 dlen 17  #80907 [hci0] 2026-10-01 00:54:45.397220
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX: H.. flags 0x00 dlen 14  #80908 [hci0] 2026-10-01 00:54:45.397358
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Command... (0x0f) plen 4  #80913 [hci0] 2026-10-01 00:54:45.421102
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)

== hci-20261001-003632.btsnoop  2026-10-01 00:55:26 .. 2026-10-01 00:55:30
< ACL Data TX:... flags 0x00 dlen 19  #108512 [hci0] 2026-10-01 00:55:27.443876
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
> HCI Event: Command.. (0x0f) plen 4  #108516 [hci0] 2026-10-01 00:55:27.449227
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconn.. (0x05) plen 4  #108536 [hci0] 2026-10-01 00:55:27.490205
        Status: Success (0x00)
        Handle: 7 Address: AA:BB:CC:00:00:02 (Sonova Consumer Hearing GmbH)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX:... flags 0x02 dlen 17  #108540 [hci0] 2026-10-01 00:55:27.519211
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX:... flags 0x00 dlen 14  #108541 [hci0] 2026-10-01 00:55:27.519285
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Command.. (0x0f) plen 4  #108547 [hci0] 2026-10-01 00:55:27.545187
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)

```

**Evidence window.** not placeable — this output carries no timestamp with a UTC offset. Re-run the extraction with `-o short-iso-precise` if the window matters.

## Provenance

| field | value |
|---|---|
| captured | `2026-10-03T03:16:03+02:00` |
| kernel | `7.0.0-34-generic` |
| capture boot id | `c34cfa10` |
| evidence boot ids | `855a927e, c34cfa10` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
