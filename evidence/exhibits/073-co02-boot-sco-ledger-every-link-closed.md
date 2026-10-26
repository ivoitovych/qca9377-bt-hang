# EX-073 — co02-boot-sco-ledger-every-link-closed

**Claim.** On the boot with the CO-02 series, from 2026-10-23 11:04 to the time of this exhibit, the kernel log shows 36 SCO link setups on three headsets, and the controller answered the host's Disconnect for each: "links 36   hang-ups answered 36   timeouts 0". The QCA firmware was loaded (rampatch and NVM) and no command timed out. *Corrected 2026-10-26:* this claim first said "the HCI capture shows … every one went down"; the ledger reads the kernel's debug text, and its "answered" line has no handle and no event status, so it does not show which link closed. That every link closed is shown from the capture, by handle, in `EX-074`. The error-level lines are the "SCO packet for unknown connection handle" and "corrupted SCO packet" messages at hang-ups. The previous boot, on the unpatched module, has the same messages (`journalctl -k -b -1 -p err --grep "unknown connection handle|corrupted SCO"`, 2026-10-20 to 2026-10-23; `CO-20`), so they predate the series; their rates on the two boots were not compared.

**Relevance.** Run 5 of the plan: patch 1 changes who holds a reused connection; a hold left behind would keep a SCO link up after both sockets close, which shows here as a link that never goes down.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/boot-bt-summary.sh 257d1599532e4cad941b5bb6178bb630
```

## Output

Verbatim, 131 line(s), exit status 0.

```
== boot 257d1599532e4cad941b5bb6178bb630
     0 257d1599532e4cad941b5bb6178bb630 Fri 2026-10-23 11:04:43 CEST Sun 2026-10-25 22:23:27 CET
== btusb loaded now: version 0.8 srcversion D1DEA96A0C95BFAB05CEE01
== firmware setup (kernel log)
2026-10-23T11:04:43+02:00 n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
2026-10-23T11:04:43+02:00 n kernel: Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
2026-10-23T11:04:43+02:00 n kernel: Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
== error-level hci0 lines (command timeouts, 0x2005, corrupted SCO, unknown handles)
2026-10-23T11:46:29+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T11:46:29+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T11:49:42+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-23T11:49:42+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-23T11:49:44+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-23T11:50:16+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-23T12:58:33+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T12:58:33+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T12:58:33+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T12:58:34+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T12:58:46+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T12:58:46+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T12:58:46+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-23T13:00:41+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T13:00:41+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T13:00:41+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T13:11:03+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
2026-10-23T13:11:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-23T13:11:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-23T13:27:12+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-23T21:11:19+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T21:11:19+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T21:11:57+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-23T21:20:34+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-23T21:20:34+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-23T21:22:12+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T21:22:12+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T21:22:53+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-23T21:36:44+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
2026-10-23T21:36:44+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
2026-10-23T21:37:20+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T21:37:20+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T21:37:20+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T21:37:20+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-23T21:37:54+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 13
2026-10-23T21:37:54+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 13
2026-10-23T22:00:33+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T22:00:33+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T22:01:16+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-23T22:12:12+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-23T23:31:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-23T23:31:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-23T23:31:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-23T23:51:31+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-23T23:51:34+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-24T06:12:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-24T06:12:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-24T06:12:47+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T06:12:50+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T06:13:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T06:13:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T06:13:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T06:37:03+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-24T06:37:03+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-24T06:37:03+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 13
2026-10-24T07:58:31+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 14
2026-10-24T07:58:31+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 14
2026-10-24T07:59:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 15
2026-10-24T08:01:37+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T08:01:37+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T08:01:37+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T08:01:37+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-24T08:01:47+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T08:01:47+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T08:01:47+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-24T08:02:25+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-24T08:02:25+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-24T08:02:32+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-24T08:02:32+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-24T08:02:32+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-24T08:02:39+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-24T08:02:39+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-24T08:02:50+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-24T08:04:59+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-24T08:08:42+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-24T08:10:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 12
2026-10-24T11:11:00+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 13
== SCO ledger
== boot 257d1599532e4cad941b5bb6178bb630
setup                       headset             air     len27/9   streamed  outcome
2026-10-23T11:45:27.569661  MOMENTUM 4          msbc      20080      61.26  hangup-ok 38 ms
2026-10-23T11:49:30.069715  MOMENTUM 4          msbc       3580      11.76  hangup-ok 8 ms
2026-10-23T11:49:58.779686  MOMENTUM 4          msbc       5975      17.95  hangup-ok 53 ms
2026-10-23T12:57:33.306672  MOMENTUM 4          msbc       3495      10.50  hangup-ok 32 ms
2026-10-23T12:58:27.304799  MOMENTUM 4          msbc       2157       6.50  hangup-ok 4 ms
2026-10-23T12:58:34.247667  MOMENTUM 4          msbc       4077      12.24  hangup-ok 85 ms
2026-10-23T13:00:30.663764  MOMENTUM 4          msbc       3540      10.65  hangup-ok 84 ms
2026-10-23T13:00:46.269666  MOMENTUM 4          msbc      16147      48.45  hangup-ok 39 ms
2026-10-23T13:11:03.971781  MOMENTUM 4          msbc       6207      18.64  hangup-ok 15 ms
2026-10-23T21:10:18.526673  MOMENTUM 4          msbc      20292      60.91  hangup-ok 46 ms
2026-10-23T21:19:54.597724  MOMENTUM 4          msbc      13280      39.87  hangup-ok 48 ms
2026-10-23T21:21:35.935710  MOMENTUM 4          msbc      12232      36.72  hangup-ok 45 ms
2026-10-23T21:36:14.447713  MOMENTUM 4          msbc       9937      29.84  hangup-ok 63 ms
2026-10-23T21:36:44.473681  MOMENTUM 4          cvsd          0      35.82  hangup-ok 51 ms
2026-10-23T21:37:20.487732  MOMENTUM 4          msbc      11255      33.79  hangup-ok 99 ms
2026-10-23T21:59:49.903745  联想thinkplus-GM2 pro  msbc      14570      43.73  hangup-ok 194 ms
2026-10-23T22:00:46.199651  联想thinkplus-GM2 pro  cvsd          0      29.95  hangup-ok 180 ms
2026-10-23T22:01:29.183748  联想thinkplus-GM2 pro  cvsd          0     643.40  hangup-ok 190 ms
2026-10-23T23:30:19.380735  联想thinkplus-GM2 pro  cvsd          0      65.12  hangup-ok 222 ms
2026-10-23T23:51:29.553753  联想thinkplus-GM2 pro  msbc        630       1.92  hangup-ok 210 ms
2026-10-23T23:53:11.234798  联想thinkplus-GM2 pro  msbc        470       1.44  hangup-ok 192 ms
2026-10-24T06:11:57.718819  联想thinkplus-GM2 pro  msbc       8165      24.54  hangup-ok 193 ms
2026-10-24T06:12:27.351720  联想thinkplus-GM2 pro  cvsd          0      20.30  hangup-ok 195 ms
2026-10-24T06:12:52.743820  联想thinkplus-GM2 pro  msbc       7525      22.59  hangup-ok 188 ms
2026-10-24T06:36:28.551762  Shure AONIC 50      msbc       5237      15.73  hangup-ok 27 ms
2026-10-24T06:36:44.456635  Shure AONIC 50      cvsd          0      18.77  hangup-ok 67 ms
2026-10-24T06:37:03.450710  Shure AONIC 50      msbc    1629072    4888.28  hangup-ok 34 ms
2026-10-24T07:58:32.155690  Shure AONIC 50      msbc       7330      22.02  hangup-ok 77 ms
2026-10-24T08:01:24.662741  Shure AONIC 50      msbc       4265      12.82  hangup-ok 57 ms
2026-10-24T08:01:37.777719  Shure AONIC 50      cvsd          0       9.85  hangup-ok 56 ms
2026-10-24T08:01:47.898733  Shure AONIC 50      msbc      12407      37.25  hangup-ok 28 ms
2026-10-24T08:02:25.411683  Shure AONIC 50      cvsd          0       6.76  hangup-ok 45 ms
2026-10-24T08:02:32.459669  Shure AONIC 50      msbc       2335       7.02  hangup-ok 15 ms
2026-10-24T08:03:51.711800  Shure AONIC 50      msbc      22367      67.13  hangup-ok 65 ms
2026-10-24T08:06:40.167888  Shure AONIC 50      msbc      40550     121.68  hangup-ok 20 ms
2026-10-24T11:10:25.948717  Shure AONIC 50      msbc        652      32.18  hangup-ok 22 ms

links 36   hang-ups answered 36   timeouts 0

TOTAL over 1 boot(s): links 36   hang-ups answered 36   timeouts 0
  联想thinkplus-GM2 pro      9
  MOMENTUM 4               15
  Shure AONIC 50           12
```

**Evidence window.** `2026-10-23T11:04:43+02:00` — `2026-10-24T11:11:00+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-25T22:29:57+01:00` |
| kernel | `7.0.0-38-generic` |
| capture boot id | `257d1599` |
| evidence boot ids | `257d1599` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
