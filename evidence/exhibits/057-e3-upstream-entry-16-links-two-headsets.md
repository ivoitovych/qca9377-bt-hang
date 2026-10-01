# EX-057 — e3-upstream-entry-16-links-two-headsets

**Claim.** With the exact upstream entry dc16388d45ec built for 7.0.0-34 (E3, srcversion 36ADEF2A3F27D16D77A320E), the controller loads the QCA rampatch and NVM and 16 SCO links on two headsets, including the Shure AONIC 50 that wedged the stock driver in EX-053, were set up and torn down with every hang-up answered: 0 command timeouts and 0 unexpected-event 0x2005 on the boot. The error-level lines that do appear are late SCO packets after each hang-up ("unknown connection handle"), one "corrupted SCO packet" during a Shure mSBC link (03:01:19), and one Disconnect answered -107 at 01:00:03 when the adapter was switched off by rfkill — none is a command timeout. (Correction to the claim as first written, which said 0 corrupted SCO packets; the output below is untouched.)

**Relevance.** This is the production form of the fix the stable backport request asks for: the same machine, the same wideband alt-1 streams, legacy 0x0428 setup, the upstream entry and nothing else changed. The error-level grep is empty, so nothing is hidden by the ledger's filters.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ /root/exp/qca9377-bt-hang/scripts/boot-bt-summary.sh 0
```

## Output

Verbatim, 65 line(s), exit status 0.

```
== boot 0
     0 c34cfa108a144b0f9b900806cb71367e Thu 2026-10-01 00:13:20 CEST Fri 2026-10-02 00:42:19 CEST
== btusb loaded now: version 0.8 srcversion 36ADEF2A3F27D16D77A320E
== firmware setup (kernel log)
2026-10-01T00:13:21+02:00 n kernel: Bluetooth: hci0: using rampatch file: qca/rampatch_usb_00000302.bin
2026-10-01T00:13:21+02:00 n kernel: Bluetooth: hci0: QCA: patch rome 0x302 build 0x3e8, firmware rome 0x302 build 0x111
2026-10-01T00:13:21+02:00 n kernel: Bluetooth: hci0: using NVM file: qca/nvm_usb_00000302.bin
== error-level hci0 lines (command timeouts, 0x2005, corrupted SCO, unknown handles)
2026-10-01T00:54:45+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-01T00:54:45+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-01T00:54:53+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-01T00:54:53+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-01T00:54:53+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-01T00:54:56+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-01T00:54:56+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-01T00:54:56+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-01T00:55:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-01T00:55:15+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-01T00:55:33+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-01T01:00:03+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-01T01:00:03+02:00 n kernel: Bluetooth: hci0: Opcode 0x0406 failed: -107
2026-10-01T03:01:16+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 3
2026-10-01T03:01:19+02:00 n kernel: Bluetooth: hci0: corrupted SCO packet
2026-10-01T03:01:19+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 4
2026-10-01T03:01:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-01T03:01:22+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 5
2026-10-01T03:01:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-01T03:01:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-01T03:01:24+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 6
2026-10-01T03:01:26+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 7
2026-10-01T03:01:36+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-01T03:01:36+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-01T03:01:36+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-10-01T03:01:39+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 9
2026-10-01T03:01:49+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-01T03:01:49+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-01T03:01:49+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 10
2026-10-01T03:02:01+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
2026-10-01T03:02:01+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
2026-10-01T03:15:57+02:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 11
== SCO ledger
== boot 0
setup                       headset             air     len27/9   streamed  outcome
2026-10-01T00:54:20.265311  MOMENTUM 4          msbc       8312      24.96  hangup-ok 37 ms
2026-10-01T00:54:45.419298  MOMENTUM 4          cvsd          0       8.22  hangup-ok 17 ms
2026-10-01T00:54:53.761280  MOMENTUM 4          cvsd          0       2.83  hangup-ok 21 ms
2026-10-01T00:54:56.987300  MOMENTUM 4          cvsd          0      18.53  hangup-ok 90 ms
2026-10-01T00:55:15.745337  MOMENTUM 4          msbc       3872      11.63  hangup-ok 46 ms
2026-10-01T00:55:27.542284  MOMENTUM 4          cvsd          0       5.44  hangup-ok 9 ms
2026-10-01T00:55:33.107307  MOMENTUM 4          cvsd          0     270.68  hangup-ok 59 ms
2026-10-01T03:00:48.857356  Shure AONIC 50      msbc       7762      23.31  hangup-ok 41 ms
2026-10-01T03:01:16.468304  Shure AONIC 50      cvsd          0       3.07  hangup-ok 6 ms
2026-10-01T03:01:19.674359  Shure AONIC 50      msbc        735       2.22  hangup-ok 6 ms
2026-10-01T03:01:22.045405  Shure AONIC 50      msbc        700       2.11  hangup-ok 10 ms
2026-10-01T03:01:24.334348  Shure AONIC 50      cvsd          0       1.56  hangup-ok 6 ms
2026-10-01T03:01:26.034294  Shure AONIC 50      cvsd          0      10.52  hangup-ok 61 ms
2026-10-01T03:01:36.812359  Shure AONIC 50      msbc        870       2.62  hangup-ok 10 ms
2026-10-01T03:01:39.612349  Shure AONIC 50      cvsd          0       9.80  hangup-ok 51 ms
2026-10-01T03:01:49.600357  Shure AONIC 50      msbc       3790      11.40  hangup-ok 61 ms

links 16   hang-ups answered 16   timeouts 0

TOTAL over 1 boot(s): links 16   hang-ups answered 16   timeouts 0
  MOMENTUM 4               7
  Shure AONIC 50           9
```

**Evidence window.** `2026-10-01T00:13:21+02:00` — `2026-10-01T03:15:57+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-10-02T00:42:59+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `c34cfa10` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
