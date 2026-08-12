# EX-009 — sco-teardown-not-setup-in-this-incident

**Claim.** In this incident the SCO link was set up SUCCESSFULLY — the controller answered 0x0428 within 2 ms, btusb switched the USB alternate setting, and the link reached `handle 0x0003`. It then carried **only 11 SCO packets, all within ~30 ms**, and nothing for the following 7 seconds. The command that was never answered was the subsequent Disconnect (0x0406) tearing that link down.

**⚠️ Correction made before publication.** This exhibit first said "voice audio flowed for 7 seconds", read from the 7-second gap between setup and teardown. The packet count contradicts it: SCO at 8 kHz should carry hundreds of packets per second, so 11 packets in 30 ms followed by silence means the link went **quiet almost immediately after being established**. The seven seconds were not seven seconds of audio; they were seven seconds of nothing. Whether that silence is a symptom of the impending failure or simply an idle voice channel is not established here.

**Relevance.** This refutes any reading of EX-006 as 'the controller cannot service SCO setup'. Here it serviced it correctly. Across the two instrumented failures the constant is SCO link handling and the accompanying USB alternate-setting switch btusb performs for isochronous bandwidth (btusb_switch_alt_setting, logged as 'Looking for Alt no'), not one specific opcode: setup went unanswered in one incident, teardown in the other. The recurring 'setting interface failed (110)' belongs to that same alt-setting path. This points at the SCO/isochronous path in btusb rather than at a single HCI command.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo '--- key events (SCO data packets collapsed) ---'; journalctl -k -b 0 --since '2026-08-12 06:26:24.9' --until '2026-08-12 06:26:41' --no-pager -o short-iso-precise | grep -iE 'opcode 0x0428|hcon .* handle 0x0003|Looking for Alt|reason 0x13|Opcode 0x0406|0x0406 tx timeout|setting interface'; echo; echo -n 'SCO data packets carried between setup and teardown: '; journalctl -k -b 0 --since '2026-08-12 06:26:25' --until '2026-08-12 06:26:32.5' --no-pager -o cat | grep -c 'SCO data packet'
```

## Output

Verbatim, 12 line(s), exit status 0.

```
--- key events (SCO data packets collapsed) ---
2026-08-12T06:26:25.001673+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-12T06:26:25.231664+02:00 n kernel: hci0: hcon 00000000d2b4b206 handle 0x0003
2026-08-12T06:26:25.231709+02:00 n kernel: Looking for Alt no :6
2026-08-12T06:26:25.231721+02:00 n kernel: Looking for Alt no :3
2026-08-12T06:26:32.543644+02:00 n kernel: hci0: handle 0x03 reason 0x13
2026-08-12T06:26:32.543736+02:00 n kernel: hci0: Opcode 0x0406
2026-08-12T06:26:32.543761+02:00 n kernel: hci0: opcode 0x0406 plen 3
2026-08-12T06:26:34.579698+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-12T06:26:39.893568+02:00 n kernel: Bluetooth: hci0: setting interface failed (110)

SCO data packets carried between setup and teardown: 11
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T06:34:29+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `7ab86388` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
