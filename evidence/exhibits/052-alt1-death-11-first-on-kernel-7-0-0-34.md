# EX-052 — alt1-death-11-first-on-kernel-7-0-0-34

**Claim.** Eleventh alt-1 death, 2026-09-25 18:32:17, the first on kernel 7.0.0-34-generic: 3605 SCO packets on alt 1 in the 12 s before the fault (all 27-byte mSBC buffers as 3x9), then the first command issued, 0x0406 Disconnect (reason 0x13) at 18:32:15.853, is never answered and times out at 18:32:17.904. Two usbfs GET_DESCRIPTOR control transfers issued by tcpdump at 18:32:37 and 18:32:42 timed out (-110) inside the window. Ended by a reboot at 18:45:23, about 13 min after the fault.

**Relevance.** Same signature as EX-033..047 and EX-051, now on a newer kernel build: the 7.0.0-31 to 7.0.0-34 update does not change this fault. The two tcpdump control transfers are a perturbation by this project's own capture and are recorded, not hidden.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl --list-boots --no-pager | grep -E '5ee9ab7846eb47afb5843cb00fb1d119'; journalctl -k -b 5ee9ab7846eb47afb5843cb00fb1d119 --no-pager -o short-iso-precise --grep 'Linux version' | head -1 | sed -E 's/.*(Linux version [^ ]+).*/\1/'; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot 5ee9ab7846eb47afb5843cb00fb1d119 --before 12 --after 3 2>&1 | head -8; echo; journalctl -k -b 5ee9ab7846eb47afb5843cb00fb1d119 --no-pager -o short-iso-precise --since '2026-09-25 18:32:15.8' --until '2026-09-25 18:32:18' --grep 'handle 0x0b reason|Opcode 0x0406|tx timeout'; echo; journalctl -k -b 5ee9ab7846eb47afb5843cb00fb1d119 --no-pager -o short-iso-precise --grep 'usbfs'
```

## Output

Verbatim, 19 line(s), exit status 0.

```
 -1 5ee9ab7846eb47afb5843cb00fb1d119 Fri 2026-09-25 15:32:27 CEST Fri 2026-09-25 18:45:23 CEST
Linux version 7.0.0-34-generic

bt-fault-window — boot 5ee9ab7846eb47afb5843cb00fb1d119, anchored on 2026-09-25T18:32:17.904156+02:00
  window: 2026-09-25 18:32:05 … 2026-09-25 18:32:20  (−12s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)       3605   of which 27-byte mSBC: 3605
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  alt-1 transparent SCO (27-byte buffers as 3×9-byte packets) — the BT-1 condition.


2026-09-25T18:32:15.853093+02:00 n kernel: hci0: handle 0x0b reason 0x13
2026-09-25T18:32:15.853129+02:00 n kernel: hci0: Opcode 0x0406
2026-09-25T18:32:17.904156+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout

2026-09-25T15:32:27.095665+02:00 n kernel: usbcore: registered new interface driver usbfs
2026-09-25T18:32:37.488047+02:00 n kernel: usb 3-3: usbfs: USBDEVFS_CONTROL failed cmd tcpdump rqt 128 rq 6 len 18 ret -110
2026-09-25T18:32:42.608063+02:00 n kernel: usb 3-3: usbfs: USBDEVFS_CONTROL failed cmd tcpdump rqt 128 rq 6 len 9 ret -110
```

**Evidence window.** `2026-09-25T15:32:27.095665+02:00` — `2026-09-25T18:32:42.608063+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-25T23:14:18+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `e90c9c57` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
