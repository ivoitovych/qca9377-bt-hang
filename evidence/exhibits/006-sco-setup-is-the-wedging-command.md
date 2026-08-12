# EX-006 — sco-setup-is-the-wedging-command

**Claim.** The controller stops answering HCI while servicing HCI_Setup_Synchronous_Connection (opcode 0x0428) — the SCO/eSCO link setup for HFP. The command is submitted, is never answered, and times out 2.169 s later.

**Relevance.** This is the first identification of a specific command at the moment of failure, made possible by kernel dynamic debug enabled from boot. It fits every prior observation: the operator switches profile between A2DP and HFP in GNOME Sound, SCO data packets are present in the preceding seconds, earlier incidents showed AVDTP/HFP fallback to mono, and 'setting interface failed' recurs across incidents — that error is btusb changing the USB alternate setting to allocate isochronous bandwidth for SCO. It suggests a minimal reproducer: force an HFP profile switch while ACL audio is streaming.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b 0 --since '2026-08-12 05:00:15' --until '2026-08-12 05:00:19' --no-pager -o short-iso-precise | grep -iE 'cmd_cnt|opcode|command tx timeout|skb len'
```

## Output

Verbatim, 6 line(s), exit status 0.

```
2026-08-12T05:00:16.595818+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-12T05:00:16.595827+02:00 n kernel: hci0: skb len 20
2026-08-12T05:00:16.595835+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 1
2026-08-12T05:00:16.706702+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 1
2026-08-12T05:00:18.764738+02:00 n kernel: Bluetooth: hci0: command tx timeout
2026-08-12T05:00:18.764759+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 0
```

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T05:18:58+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `c1315c25` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
