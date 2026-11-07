# EX-067 — co02-earbuds-codec-switch-refused-then-new-link

**Claim.** With the CO-02 series loaded (Ubuntu 7.0.0-38 Bluetooth with abd93c85c8667, 816fb1590a4c and the three patches; boot 257d1599), at each of three HFP codec switches on the Lenovo earbuds the headset's AT+BCS= reply came before the old link's Disconnection Complete, no Setup Synchronous Connection was sent for the switch, and a new link was set up later: 2026-10-23 22:00:33 (mSBC to CVSD, Disconnection Complete .871565, no stream playing, the next link at 22:00:46.198849 when a test sound started), 2026-10-24 06:12:22 (mSBC to CVSD with a stream playing, Disconnection Complete .491861, new link 06:12:27.350650, CVSD) and 06:12:47 (CVSD to mSBC with a stream playing, Disconnection Complete .886915, new link 06:12:52.743599, Transparent).

**Relevance.** This is the case the series changes (U7, EX-060): before it, the new socket was reported connected on the dying link and no link followed. Here no setup is sent on the dying link, and with a stream playing a fresh link comes 4.86 s after the Disconnection Complete, set up from scratch (new handles 6 and 7). EX-068 shows the connect() refusals and what started the new link.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/sco-switch-windows.sh /var/log/bt-health/capture/hci-20261023-214733.btsnoop "2026-10-23 22:00:33" "2026-10-23 22:00:47" /var/log/bt-health/capture/hci-20261023-233436.btsnoop "2026-10-24 06:12:22" "2026-10-24 06:12:40" /var/log/bt-health/capture/hci-20261023-233436.btsnoop "2026-10-24 06:12:47" "2026-10-24 06:13:00"
```

## Output

Verbatim, 195 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
== hci-20261023-214733.btsnoop  2026-10-23 22:00:33 .. 2026-10-23 22:00:47
< ACL Data TX: Handle 2 flags 0x00 dlen 19                                                                             #75793 [hci0] 2026-10-23 22:00:33.676146
      Channel: 75 len 15 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x13 cr 1 dlci 0x04
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x65
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 65              ..+BCS: 1..e    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                         #75794 [hci0] 2026-10-23 22:00:33.676159
        Handle: 3 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                              #75795 [hci0] 2026-10-23 22:00:33.678431
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> ACL Data RX: Handle 2 flags 0x02 dlen 18                                                                             #75811 [hci0] 2026-10-23 22:00:33.710561
      Channel: 65 len 14 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x11 cr 0 dlci 0x04
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xbf
        41 54 2b 42 43 53 3d 31 0d bf                    AT+BCS=1..      
< ACL Data TX: Handle 2 flags 0x00 dlen 14                                                                             #75812 [hci0] 2026-10-23 22:00:33.710833
      Channel: 75 len 10 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x13 cr 1 dlci 0x04
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x65
        0d 0a 4f 4b 0d 0a 65                             ..OK..e         
> HCI Event: Disconnect Complete (0x05) plen 4                                                                         #75868 [hci0] 2026-10-23 22:00:33.871565
        Status: Success (0x00)
        Handle: 3 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Connection Terminated By Local Host (0x16)
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                      #75879 [hci0] 2026-10-23 22:00:46.198849
        Handle: 2 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Transmit bandwidth: 8000
        Receive bandwidth: 8000
        Max latency: 10
        Setting: 0x0060
          Input Coding: Linear
          Input Data Format: 2's complement
          Input Sample Size: 16-bit
          # of bits padding at MSB: 0
          Air Coding Format: CVSD
        Retransmission effort: Optimize for power consumption (0x01)
        Packet type: 0x0380
          3-EV3 may not be used
          2-EV5 may not be used
          3-EV5 may not be used
> HCI Event: Command Status (0x0f) plen 4                                                                              #75880 [hci0] 2026-10-23 22:00:46.201470
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #75883 [hci0] 2026-10-23 22:00:46.221430
        Status: Success (0x00)
        Handle: 4
        Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261023-233436.btsnoop  2026-10-24 06:12:22 .. 2026-10-24 06:12:40
< ACL Data TX: Handle 3 flags 0x00 dlen 19                                                                            #111726 [hci0] 2026-10-24 06:12:22.298580
      Channel: 67 len 15 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #111727 [hci0] 2026-10-24 06:12:22.298592
        Handle: 5 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #111728 [hci0] 2026-10-24 06:12:22.300837
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> ACL Data RX: Handle 3 flags 0x02 dlen 18                                                                            #111741 [hci0] 2026-10-24 06:12:22.324563
      Channel: 65 len 14 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX: Handle 3 flags 0x00 dlen 14                                                                            #111742 [hci0] 2026-10-24 06:12:22.324714
      Channel: 67 len 10 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #111799 [hci0] 2026-10-24 06:12:22.491861
        Status: Success (0x00)
        Handle: 5 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Connection Terminated By Local Host (0x16)
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #111803 [hci0] 2026-10-24 06:12:27.350650
        Handle: 3 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Transmit bandwidth: 8000
        Receive bandwidth: 8000
        Max latency: 10
        Setting: 0x0060
          Input Coding: Linear
          Input Data Format: 2's complement
          Input Sample Size: 16-bit
          # of bits padding at MSB: 0
          Air Coding Format: CVSD
        Retransmission effort: Optimize for power consumption (0x01)
        Packet type: 0x0380
          3-EV3 may not be used
          2-EV5 may not be used
          3-EV5 may not be used
> HCI Event: Command Status (0x0f) plen 4                                                                             #111805 [hci0] 2026-10-24 06:12:27.351846
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #111807 [hci0] 2026-10-24 06:12:27.386887
        Status: Success (0x00)
        Handle: 6
        Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261023-233436.btsnoop  2026-10-24 06:12:47 .. 2026-10-24 06:13:00
< ACL Data TX: Handle 3 flags 0x00 dlen 19                                                                            #125343 [hci0] 2026-10-24 06:12:47.690751
      Channel: 67 len 15 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 32 0d 0a 3e              ..+BCS: 2..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #125344 [hci0] 2026-10-24 06:12:47.690774
        Handle: 6 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #125345 [hci0] 2026-10-24 06:12:47.693959
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> ACL Data RX: Handle 3 flags 0x02 dlen 18                                                                            #125355 [hci0] 2026-10-24 06:12:47.714559
      Channel: 65 len 14 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 32 0d e4                    AT+BCS=2..      
< ACL Data TX: Handle 3 flags 0x00 dlen 14                                                                            #125356 [hci0] 2026-10-24 06:12:47.714712
      Channel: 67 len 10 [PSM 3 mode Basic (0x00)] {chan 5}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #125415 [hci0] 2026-10-24 06:12:47.886915
        Status: Success (0x00)
        Handle: 6 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
        Reason: Connection Terminated By Local Host (0x16)
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #125419 [hci0] 2026-10-24 06:12:52.743599
        Handle: 3 Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #125421 [hci0] 2026-10-24 06:12:52.745900
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #125423 [hci0] 2026-10-24 06:12:52.786897
        Status: Success (0x00)
        Handle: 7
        Address: AA:BB:CC:00:00:01 (OUI 41-42-FF)
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
| captured | `2026-10-25T22:19:15+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
