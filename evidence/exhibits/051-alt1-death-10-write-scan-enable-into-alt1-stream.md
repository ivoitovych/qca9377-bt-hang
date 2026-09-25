# EX-051 — alt1-death-10-write-scan-enable-into-alt1-stream

**Claim.** Tenth alt-1 death, 2026-09-25 15:29:23, kernel 7.0.0-31-generic, stock bluetooth.ko: SCO set up 3.672 s before the fault, 1859 SCO packets on alt 1 in the 12 s window (1857 of them 27-byte mSBC buffers as 3x9), then the first command issued into the stream, 0x0c1a Write Scan Enable at 15:29:21.954, is never answered and times out at 15:29:23.974; setup to fault 3.672 s. Ended by a reboot at 15:31:52.

**Relevance.** Same signature as EX-033..047, but the command that died is Write Scan Enable, not Disconnect: the fault follows the first command issued into the alt-1 stream, whatever its opcode (EX-043).

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl --list-boots --no-pager | grep -E 'ef992099621e49cbbf4e20f8a182215c'; journalctl -k -b ef992099621e49cbbf4e20f8a182215c --no-pager -o short-iso-precise --grep 'Linux version' | head -1 | sed -E 's/.*(Linux version [^ ]+).*/\1/'; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot ef992099621e49cbbf4e20f8a182215c --before 12 --after 3 2>&1 | head -8; echo; journalctl -k -b ef992099621e49cbbf4e20f8a182215c --no-pager -o short-iso-precise --since '2026-09-25 15:29:21.9' --until '2026-09-25 15:29:24' --grep 'Opcode 0x0c1a|tx timeout'; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot ef992099621e49cbbf4e20f8a182215c --before 12 --after 3 2>&1 | tail -2
```

## Output

Verbatim, 18 line(s), exit status 0.

```
 -2 ef992099621e49cbbf4e20f8a182215c Thu 2026-09-24 09:00:05 CEST Fri 2026-09-25 15:31:52 CEST
Linux version 7.0.0-31-generic

bt-fault-window — boot ef992099621e49cbbf4e20f8a182215c, anchored on 2026-09-25T15:29:23.974580+02:00
  window: 2026-09-25 15:29:11 … 2026-09-25 15:29:26  (−12s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)       1859   of which 27-byte mSBC: 1857
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  alt-1 transparent SCO (27-byte buffers as 3×9-byte packets) — the BT-1 condition.


2026-09-25T15:29:21.954629+02:00 n kernel: hci0: Opcode 0x0c1a
2026-09-25T15:29:23.974580+02:00 n kernel: Bluetooth: hci0: command 0x0c1a tx timeout
2026-09-25T15:29:23.974663+02:00 n kernel: Bluetooth: hci0: Opcode 0x0c1a failed: -110

  0x0428 setup → fault: 3.672 s
    for comparison: EX-033 2.076  EX-036 2.152  EX-037 2.151  EX-038 2.191
```

**Evidence window.** `2026-09-25T15:29:21.954629+02:00` — `2026-09-25T15:29:23.974580+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-25T23:13:52+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `e90c9c57` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
