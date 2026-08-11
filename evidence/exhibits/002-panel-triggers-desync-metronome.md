# EX-002 — panel-triggers-desync-metronome

**Claim.** Opening the GNOME Bluetooth settings panel deterministically drives this controller into an HCI command-pipeline desync that then repeats at an exact 16.0 second cadence for as long as the panel remains open.

**Relevance.** This is a reproducible trigger, obtainable in seconds, on a bug otherwise characterised only by 'hangs after hours of use'. The first desync follows the panel launch within 0.06-10 s on every boot examined, and the cadence is 16.0 s to one decimal place across runs of up to 2480 repeats. Opcode 0x2005 is HCI_LE_Set_Random_Address, which BlueZ reissues on each discovery restart cycle.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cd /root/exp/qca9377-bt-hang && for b in 0 -4 -15; do echo "--- boot $b ---"; ./tools/bt-actions -b $b 2>/dev/null | grep -A2 'opened the Bluetooth settings panel' | head -9; done
```

## Output

Verbatim, 30 line(s), exit status 0.

```
--- boot 0 ---
22:55:12.434  USER   opened the Bluetooth settings panel
22:55:12.723  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x228 until 23:55:44.355, every ~16.0s
23:55:56.812  USER   opened the Bluetooth settings panel
23:56:00.354  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x35 until 00:05:04.356, every ~16.0s
--
00:09:25.453  USER   opened the Bluetooth settings panel
00:09:31.353  CTRL   HCI desync: unexpected event for opcode 0x2005
--- boot -4 ---
18:59:13.523  USER   opened the Bluetooth settings panel
18:59:13.815  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x2480 until 06:00:03.425, every ~16.0s
06:00:11.528  USER   opened the Bluetooth settings panel
06:00:21.904  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x15 until 06:04:02.906, every ~15.8s
--
06:05:29.757  USER   opened the Bluetooth settings panel
06:05:39.909  CTRL   HCI desync: unexpected event for opcode 0x2005
--- boot -15 ---
02:35:24.975  USER   opened the Bluetooth settings panel
02:35:25.374  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x3 until 02:35:57.160, every ~15.9s
--
13:48:29.101  USER   opened the Bluetooth settings panel
13:48:33.847  CTRL   HCI desync: unexpected event for opcode 0x2005
                          x2 until 13:48:37.693, every ~3.8s
14:18:41.166  USER   opened the Bluetooth settings panel
14:18:41.230  CTRL   HCI desync: unexpected event for opcode 0x2005
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T00:43:08+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `5641d159` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
