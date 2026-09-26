# EX-056 — e1-seven-wideband-disconnects-answered

**Claim.** With the E1 diagnostic btusb (0.8-e1: QCA ROME setup, rampatch build 0x3e8 + NVM loaded, EX-055) on 7.0.0-34, boot 226965f1, 2026-09-26 21:52-21:55: seven transparent (wideband) SCO links set up by legacy 0x0428 (evt 5, 'Looking for Alt no :6' then ':3', i.e. alt 1), 15273 alt-1 buffers of 27 bytes as 3x9 in that span, and each link ended by 0x0406 Disconnect (reason 0x13) that the controller answered with status 0x00; zero command timeouts this boot. On the stock driver (ROM firmware build 0x111) that first command after a wideband alt-1 stream timed out in 12 of 12 recorded instances (EX-033..EX-053).

**Relevance.** The failing conditions were kept intact — legacy 0x0428, wideband, alt 1, the same 27 -> 9+9+9 framing — and only the QCA firmware setup was added. The command that always died now completes. n = 7 links on one boot with one headset (MOMENTUM 4, per the operator's screenshot of the sound settings, not this output): strong, not yet a denominator. Four further 0x0428 setups in the window (21:53:16, 21:53:39, 21:54:01, 21:55:15) are CVSD links (btusb notification evt 4, HCI_NOTIFY_ENABLE_SCO_CVSD — not matched by this extraction's grep), also each ended by an answered 0x0406; they are not counted above.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ cat /sys/module/btusb/version; echo; journalctl -k -b 226965f1219c426a950d71e6845deb6d --no-pager --since '2026-09-26 21:52' --until '2026-09-26 21:56' --grep 'len 27 mtu 9' -q | wc -l; echo; journalctl -k -b 226965f1219c426a950d71e6845deb6d --no-pager -o short-iso-precise --since '2026-09-26 21:52' --until '2026-09-26 21:56' --grep 'opcode 0x0428|evt 5|Looking for Alt no :3|reason 0x13|opcode 0x0406 status|tx timeout'; echo; echo "command timeouts this boot: $(journalctl -k -b 226965f1219c426a950d71e6845deb6d --no-pager --grep 'tx timeout' -q | wc -l)"
```

## Output

Verbatim, 53 line(s), exit status 0.

```
0.8-e1

15273

2026-09-26T21:52:50.121505+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:52:50.224596+02:00 n kernel: hci0 evt 5
2026-09-26T21:52:50.224674+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:53:01.069560+02:00 n kernel: hci0: handle 0x06 reason 0x13
2026-09-26T21:53:01.128405+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:12.290578+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:12.363514+02:00 n kernel: hci0 evt 5
2026-09-26T21:53:12.363568+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:53:16.121480+02:00 n kernel: hci0: handle 0x07 reason 0x13
2026-09-26T21:53:16.127400+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:16.169517+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:23.502581+02:00 n kernel: hci0: handle 0x08 reason 0x13
2026-09-26T21:53:23.539421+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:23.582640+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:23.662550+02:00 n kernel: hci0 evt 5
2026-09-26T21:53:23.662591+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:53:33.709556+02:00 n kernel: hci0: handle 0x09 reason 0x13
2026-09-26T21:53:33.720406+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:33.744602+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:33.819656+02:00 n kernel: hci0 evt 5
2026-09-26T21:53:33.819720+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:53:36.310456+02:00 n kernel: hci0: handle 0x0a reason 0x13
2026-09-26T21:53:36.319408+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:36.349638+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:36.419570+02:00 n kernel: hci0 evt 5
2026-09-26T21:53:36.419634+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:53:39.063446+02:00 n kernel: hci0: handle 0x0b reason 0x13
2026-09-26T21:53:39.070418+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:39.113547+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:42.555467+02:00 n kernel: hci0: handle 0x0c reason 0x13
2026-09-26T21:53:42.579526+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:53:55.111512+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:53:55.370567+02:00 n kernel: hci0 evt 5
2026-09-26T21:53:55.370606+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:54:00.881441+02:00 n kernel: hci0: handle 0x0d reason 0x13
2026-09-26T21:54:00.979453+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:54:01.026556+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:54:06.765497+02:00 n kernel: hci0: handle 0x0e reason 0x13
2026-09-26T21:54:06.829398+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:55:05.013703+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:55:05.089524+02:00 n kernel: hci0 evt 5
2026-09-26T21:55:05.089601+02:00 n kernel: Looking for Alt no :3
2026-09-26T21:55:15.784585+02:00 n kernel: hci0: handle 0x0f reason 0x13
2026-09-26T21:55:15.859469+02:00 n kernel: opcode 0x0406 status 0x00
2026-09-26T21:55:15.894592+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-26T21:55:24.265446+02:00 n kernel: hci0: handle 0x10 reason 0x13
2026-09-26T21:55:24.319399+02:00 n kernel: opcode 0x0406 status 0x00

command timeouts this boot: 0
```

**Evidence window.** `2026-09-26T21:52:50.121505+02:00` — `2026-09-26T21:55:24.265446+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-26T21:58:29+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `226965f1` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
