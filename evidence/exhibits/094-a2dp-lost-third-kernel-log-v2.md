# EX-094 — a2dp-lost-third-kernel-log-v2

**Claim.** Corrects EX-093, whose claim was wrong: from 14:00 on 2026-11-13 the kernel's only error lines are four 'SCO packet for unknown connection handle 8' (14:21:02.691 to 14:21:05.123), after the host disconnected eSCO handle 8 at 14:21:02.673 (EX-095). There is no HCI command timeout, and the A2DP loss at 14:19:53 has no kernel line.

**Relevance.** The A2DP loss is userspace (U12). The SCO lines are the late-data race already seen under U15 (handle 4) and on 10-13: the SCO counterpart of BT-6.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b af3f984071f14b89b609ce65e6cc8799 -p err --since '2026-11-13 14:00' --no-pager -o short-iso-precise
```

## Output

Verbatim, 4 line(s), exit status 0.

```
2026-11-13T14:21:02.691251+01:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-11-13T14:21:02.691309+01:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-11-13T14:21:02.691338+01:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
2026-11-13T14:21:05.123141+01:00 n kernel: Bluetooth: hci0: SCO packet for unknown connection handle 8
```

**Evidence window.** `2026-11-13T14:21:02.691251+01:00` — `2026-11-13T14:21:05.123141+01:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-11-13T14:31:20+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
