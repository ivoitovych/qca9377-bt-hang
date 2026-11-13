# EX-093 — a2dp-lost-third-kernel-log-clean

> **Superseded by EX-094 (2026-11-13).** This claim was written before the output was read,
> and the output contradicts it: four `SCO packet for unknown connection handle 8` lines.
> The command and output below are kept unchanged.

**Claim.** No kernel error and no HCI command timeout on boot af3f9840 from 14:00 to the time of capture, 2026-11-13: the controller is not involved.

**Relevance.** Separates U12 (userspace) from BT-1/BT-17 (controller).

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
| captured | `2026-11-13T14:30:44+01:00` |
| kernel | `7.0.0-43-generic` |
| capture boot id | `af3f9840` |
| evidence boot ids | `af3f9840` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
