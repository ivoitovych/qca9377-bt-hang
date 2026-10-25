# EX-070 — co02-momentum-and-shure-switches-get-a-new-link

**Claim.** With the CO-02 series loaded, every HFP codec switch on the two headsets whose AT+BCS= reply comes after the old link is gone got a new link with no refusal: the MOMENTUM 4 at 2026-10-23 21:36:44 (Disconnection Complete .427783, AT+BCS= .450840, Setup Synchronous Connection .472998, CVSD) and 21:37:20 (.427832, .463629, .487071, Transparent); the Shure AONIC 50 at 2026-10-24 06:36:44, 06:37:03, 08:01:37, 08:01:47, 08:02:25 and 08:02:32.

**Relevance.** The no-regression check: on these headsets the series leaves the switch as it was on the unpatched kernel (EX-060's MOMENTUM case), a fresh Setup Synchronous Connection about 23 ms after the AG's OK. EX-069 shows no refusal for any of them.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/sco-switch-windows.sh /var/log/bt-health/capture/hci-20261023-212905.btsnoop "2026-10-23 21:36:43" "2026-10-23 21:36:46" /var/log/bt-health/capture/hci-20261023-212905.btsnoop "2026-10-23 21:37:19" "2026-10-23 21:37:22" /var/log/bt-health/capture/hci-20261024-062043.btsnoop "2026-10-24 06:36:44" "2026-10-24 06:36:47" /var/log/bt-health/capture/hci-20261024-062043.btsnoop "2026-10-24 06:37:03" "2026-10-24 06:37:06" /var/log/bt-health/capture/hci-20261024-075517.btsnoop "2026-10-24 08:01:37" "2026-10-24 08:01:40" /var/log/bt-health/capture/hci-20261024-075517.btsnoop "2026-10-24 08:01:47" "2026-10-24 08:01:50" /var/log/bt-health/capture/hci-20261024-075517.btsnoop "2026-10-24 08:02:25" "2026-10-24 08:02:28" /var/log/bt-health/capture/hci-20261024-075517.btsnoop "2026-10-24 08:02:32" "2026-10-24 08:02:35"
```

## Output

Verbatim, 490 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
== hci-20261023-212905.btsnoop  2026-10-23 21:36:43 .. 2026-10-23 21:36:46
< ACL Data TX: Handle 6 flags 0x00 dlen 19                                                                             #64943 [hci0] 2026-10-23 21:36:44.364406
      Channel: 258 len 15 [PSM 0 mode Basic (0x00)] {chan 65535}
        69 ef 17 0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e     i....+BCS: 1..> 
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                         #64945 [hci0] 2026-10-23 21:36:44.366712
        Handle: 11 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                              #64946 [hci0] 2026-10-23 21:36:44.369698
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                         #64969 [hci0] 2026-10-23 21:36:44.427783
        Status: Success (0x00)
        Handle: 11 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 6 flags 0x02 dlen 17                                                                             #64975 [hci0] 2026-10-23 21:36:44.450840
      Channel: 64 len 13 [PSM 0 mode Basic (0x00)] {chan 65535}
        6b ef 13 41 54 2b 42 43 53 3d 31 0d e4           k..AT+BCS=1..   
< ACL Data TX: Handle 6 flags 0x00 dlen 14                                                                             #64976 [hci0] 2026-10-23 21:36:44.451034
      Channel: 258 len 10 [PSM 0 mode Basic (0x00)] {chan 65535}
        69 ef 0d 0d 0a 4f 4b 0d 0a 3e                    i....OK..>      
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                      #64978 [hci0] 2026-10-23 21:36:44.472998
        Handle: 6
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
> HCI Event: Command Status (0x0f) plen 4                                                                              #64982 [hci0] 2026-10-23 21:36:44.477738
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #64985 [hci0] 2026-10-23 21:36:44.550745
        Status: Success (0x00)
        Handle: 12
        Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261023-212905.btsnoop  2026-10-23 21:37:19 .. 2026-10-23 21:37:22
< ACL Data TX: Handle 6 flags 0x00 dlen 19                                                                             #88875 [hci0] 2026-10-23 21:37:20.376186
      Channel: 258 len 15 [PSM 0 mode Basic (0x00)] {chan 65535}
        69 ef 17 0d 0a 2b 42 43 53 3a 20 32 0d 0a 3e     i....+BCS: 2..> 
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                         #88877 [hci0] 2026-10-23 21:37:20.378879
        Handle: 12 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                              #88878 [hci0] 2026-10-23 21:37:20.381818
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                         #88897 [hci0] 2026-10-23 21:37:20.427832
        Status: Success (0x00)
        Handle: 12 Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 6 flags 0x02 dlen 17                                                                             #88902 [hci0] 2026-10-23 21:37:20.463629
      Channel: 64 len 13 [PSM 0 mode Basic (0x00)] {chan 65535}
        6b ef 13 41 54 2b 42 43 53 3d 32 0d e4           k..AT+BCS=2..   
< ACL Data TX: Handle 6 flags 0x00 dlen 14                                                                             #88903 [hci0] 2026-10-23 21:37:20.464042
      Channel: 258 len 10 [PSM 0 mode Basic (0x00)] {chan 65535}
        69 ef 0d 0d 0a 4f 4b 0d 0a 3e                    i....OK..>      
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                      #88906 [hci0] 2026-10-23 21:37:20.487071
        Handle: 6
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
> HCI Event: Command Status (0x0f) plen 4                                                                              #88908 [hci0] 2026-10-23 21:37:20.489782
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                               #88912 [hci0] 2026-10-23 21:37:20.562843
        Status: Success (0x00)
        Handle: 13
        Address: AA:BB:CC:00:00:01 (Sonova Consumer Hearing GmbH)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)

== hci-20261024-062043.btsnoop  2026-10-24 06:36:44 .. 2026-10-24 06:36:47
< ACL Data TX: Handle 11 flags 0x00 dlen 19                                                                           #128231 [hci0] 2026-10-24 06:36:44.367572
      Channel: 257 len 15 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x53 cr 1 dlci 0x14
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x31
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 31              ..+BCS: 1..1    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #128233 [hci0] 2026-10-24 06:36:44.370685
        Handle: 12 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #128237 [hci0] 2026-10-24 06:36:44.373652
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #128247 [hci0] 2026-10-24 06:36:44.394622
        Status: Success (0x00)
        Handle: 12 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 11 flags 0x02 dlen 17                                                                           #128251 [hci0] 2026-10-24 06:36:44.424559
      Channel: 65 len 13 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x51 cr 0 dlci 0x14
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xeb
        41 54 2b 42 43 53 3d 31 0d eb                    AT+BCS=1..      
< ACL Data TX: Handle 11 flags 0x00 dlen 14                                                                           #128252 [hci0] 2026-10-24 06:36:44.424732
      Channel: 257 len 10 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x53 cr 1 dlci 0x14
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x31
        0d 0a 4f 4b 0d 0a 31                             ..OK..1         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #128255 [hci0] 2026-10-24 06:36:44.456216
        Handle: 11 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #128257 [hci0] 2026-10-24 06:36:44.458647
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #128261 [hci0] 2026-10-24 06:36:44.548701
        Status: Success (0x00)
        Handle: 13
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261024-062043.btsnoop  2026-10-24 06:37:03 .. 2026-10-24 06:37:06
< ACL Data TX: Handle 11 flags 0x00 dlen 19                                                                           #140784 [hci0] 2026-10-24 06:37:03.317046
      Channel: 257 len 15 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x53 cr 1 dlci 0x14
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x31
        0d 0a 2b 42 43 53 3a 20 32 0d 0a 31              ..+BCS: 2..1    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #140786 [hci0] 2026-10-24 06:37:03.319724
        Handle: 13 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #140790 [hci0] 2026-10-24 06:37:03.322690
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #140813 [hci0] 2026-10-24 06:37:03.384621
        Status: Success (0x00)
        Handle: 13 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 11 flags 0x02 dlen 17                                                                           #140818 [hci0] 2026-10-24 06:37:03.426581
      Channel: 65 len 13 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x51 cr 0 dlci 0x14
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xeb
        41 54 2b 42 43 53 3d 32 0d eb                    AT+BCS=2..      
< ACL Data TX: Handle 11 flags 0x00 dlen 14                                                                           #140819 [hci0] 2026-10-24 06:37:03.426948
      Channel: 257 len 10 [PSM 3 mode Basic (0x00)] {chan 1}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x53 cr 1 dlci 0x14
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x31
        0d 0a 4f 4b 0d 0a 31                             ..OK..1         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #140821 [hci0] 2026-10-24 06:37:03.450404
        Handle: 11 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #140824 [hci0] 2026-10-24 06:37:03.452610
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #140828 [hci0] 2026-10-24 06:37:03.530667
        Status: Success (0x00)
        Handle: 14
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)

== hci-20261024-075517.btsnoop  2026-10-24 08:01:37 .. 2026-10-24 08:01:40
< ACL Data TX: Handle 4 flags 0x00 dlen 19                                                                            #198285 [hci0] 2026-10-24 08:01:37.653760
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #198287 [hci0] 2026-10-24 08:01:37.656704
        Handle: 6 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #198288 [hci0] 2026-10-24 08:01:37.659648
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #198307 [hci0] 2026-10-24 08:01:37.711609
        Status: Success (0x00)
        Handle: 6 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 4 flags 0x02 dlen 17                                                                            #198315 [hci0] 2026-10-24 08:01:37.741583
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX: Handle 4 flags 0x00 dlen 14                                                                            #198316 [hci0] 2026-10-24 08:01:37.741757
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #198319 [hci0] 2026-10-24 08:01:37.777474
        Handle: 4 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #198321 [hci0] 2026-10-24 08:01:37.779634
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #198325 [hci0] 2026-10-24 08:01:37.940671
        Status: Success (0x00)
        Handle: 7
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261024-075517.btsnoop  2026-10-24 08:01:47 .. 2026-10-24 08:01:50
< ACL Data TX: Handle 4 flags 0x00 dlen 19                                                                            #204896 [hci0] 2026-10-24 08:01:47.786639
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 32 0d 0a 3e              ..+BCS: 2..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #204898 [hci0] 2026-10-24 08:01:47.789741
        Handle: 7 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #204899 [hci0] 2026-10-24 08:01:47.792704
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #204918 [hci0] 2026-10-24 08:01:47.842681
        Status: Success (0x00)
        Handle: 7 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 4 flags 0x02 dlen 17                                                                            #204925 [hci0] 2026-10-24 08:01:47.865629
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 32 0d e4                    AT+BCS=2..      
< ACL Data TX: Handle 4 flags 0x00 dlen 14                                                                            #204926 [hci0] 2026-10-24 08:01:47.865862
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #204929 [hci0] 2026-10-24 08:01:47.898604
        Handle: 4 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #204931 [hci0] 2026-10-24 08:01:47.901676
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #204935 [hci0] 2026-10-24 08:01:48.088693
        Status: Success (0x00)
        Handle: 8
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x04
        RX packet length: 60
        TX packet length: 60
        Air mode: Transparent (0x03)

== hci-20261024-075517.btsnoop  2026-10-24 08:02:25 .. 2026-10-24 08:02:28
< ACL Data TX: Handle 4 flags 0x00 dlen 19                                                                            #229773 [hci0] 2026-10-24 08:02:25.338450
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 31 0d 0a 3e              ..+BCS: 1..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #229775 [hci0] 2026-10-24 08:02:25.340867
        Handle: 8 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #229779 [hci0] 2026-10-24 08:02:25.343831
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #229789 [hci0] 2026-10-24 08:02:25.366813
        Status: Success (0x00)
        Handle: 8 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 4 flags 0x02 dlen 17                                                                            #229795 [hci0] 2026-10-24 08:02:25.389568
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 31 0d e4                    AT+BCS=1..      
< ACL Data TX: Handle 4 flags 0x00 dlen 14                                                                            #229796 [hci0] 2026-10-24 08:02:25.389738
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #229798 [hci0] 2026-10-24 08:02:25.411321
        Handle: 4 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #229800 [hci0] 2026-10-24 08:02:25.413806
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #229805 [hci0] 2026-10-24 08:02:25.614848
        Status: Success (0x00)
        Handle: 9
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Link type: eSCO (0x02)
        Transmission interval: 0x0c
        Retransmission window: 0x02
        RX packet length: 60
        TX packet length: 60
        Air mode: CVSD (0x02)

== hci-20261024-075517.btsnoop  2026-10-24 08:02:32 .. 2026-10-24 08:02:35
< ACL Data TX: Handle 4 flags 0x00 dlen 19                                                                            #234313 [hci0] 2026-10-24 08:02:32.371013
      Channel: 258 len 15 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 11
         FCS: 0x3e
        0d 0a 2b 42 43 53 3a 20 32 0d 0a 3e              ..+BCS: 2..>    
< HCI Command: Disconnect (0x01|0x0006) plen 3                                                                        #234315 [hci0] 2026-10-24 08:02:32.374172
        Handle: 9 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Remote User Terminated Connection (0x13)
> HCI Event: Command Status (0x0f) plen 4                                                                             #234316 [hci0] 2026-10-24 08:02:32.376903
      Disconnect (0x01|0x0006) ncmd 1
        Status: Success (0x00)
> HCI Event: Disconnect Complete (0x05) plen 4                                                                        #234331 [hci0] 2026-10-24 08:02:32.416880
        Status: Success (0x00)
        Handle: 9 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
        Reason: Connection Terminated By Local Host (0x16)
> ACL Data RX: Handle 4 flags 0x02 dlen 17                                                                            #234339 [hci0] 2026-10-24 08:02:32.439554
      Channel: 64 len 13 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x6b cr 1 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 9
         FCS: 0xe4
        41 54 2b 42 43 53 3d 32 0d e4                    AT+BCS=2..      
< ACL Data TX: Handle 4 flags 0x00 dlen 14                                                                            #234340 [hci0] 2026-10-24 08:02:32.439741
      Channel: 258 len 10 [PSM 3 mode Basic (0x00)] {chan 0}
      RFCOMM: Unnumbered Info with Header Check (UIH) (0xef)
         Address: 0x69 cr 0 dlci 0x1a
         Control: 0xef poll/final 0
         Length: 6
         FCS: 0x3e
        0d 0a 4f 4b 0d 0a 3e                             ..OK..>         
< HCI Command: Setup Synchronous Connection (0x01|0x0028) plen 17                                                     #234342 [hci0] 2026-10-24 08:02:32.459389
        Handle: 4 Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
> HCI Event: Command Status (0x0f) plen 4                                                                             #234344 [hci0] 2026-10-24 08:02:32.461873
      Setup Synchronous Connection (0x01|0x0028) ncmd 1
        Status: Success (0x00)
> HCI Event: Synchronous Connect Complete (0x2c) plen 17                                                              #234349 [hci0] 2026-10-24 08:02:32.590881
        Status: Success (0x00)
        Handle: 10
        Address: AA:BB:CC:00:00:02 (SHURE INCORPORATED)
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
| captured | `2026-10-25T22:20:51+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
