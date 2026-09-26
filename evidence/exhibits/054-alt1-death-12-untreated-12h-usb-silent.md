# EX-054 — alt1-death-12-untreated-12h-usb-silent

**Claim.** The EX-053 wedge (fault 2026-09-26 02:09:46, kernel 7.0.0-34, stock btusb) was left untreated for 12 h 34 min: the controller stayed enumerated on the USB bus, the USB layer logged nothing after the fault, neither tooling nor operator intervened (6 command timeouts in the window); sysfs still reads bAlternateSetting 1 / wMaxPacketSize 0009. The window is closed by the power-off for the E1 btusb build, right after this capture. (The one line the journal grep returns is an unrelated AppArmor message containing "disconnect"; the USB-layer count is 0.)

**Relevance.** A natural USB collapse was never observed in the earlier long windows (EX-023, 025, 029, 042); this one, on a newer kernel and a third headset, again shows none: the wedge is a stable, silent non-response, not a slow USB failure.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ uname -r; cat /sys/module/btusb/version; echo; /root/exp/qca9377-bt-hang/tools/bt-window 2>&1 | head -10; echo; /root/exp/qca9377-bt-hang/tools/bt-usbstate 2>&1 | grep -E '^bt-usbstate|interface 3-3:1.1|bAlternateSetting       1|wMaxPacketSize       0009'; echo; journalctl -k -b e90c9c57bebe4438ad3d4087f074eba0 --no-pager -o short-iso-precise --since '2026-09-26 02:09:46' --grep 'usb 3-3|usbfs|reset|disconnect' | head -5; echo "usb-layer lines since the fault: $(journalctl -k -b e90c9c57bebe4438ad3d4087f074eba0 --no-pager --since '2026-09-26 02:09:46' --grep 'usb 3-3|usbfs' -q | wc -l)"
```

## Output

Verbatim, 22 line(s), exit status 0.

```
7.0.0-34-generic
0.8

HCI non-response window
  first timeout      2026-09-26T02:09:46.067797+02:00
  now                2026-09-26T14:44:12+02:00
  elapsed            45265.932s
  command timeouts   6

  ✓ still enumerated  13d3:3503 is on the USB bus
  ✓ USB layer silent  no bus-level line since the fault
  ✓ no intervention  neither tooling nor operator has touched it


bt-usbstate — 3-3 at 2026-09-26T14:44:12+02:00
interface 3-3:1.1
  bAlternateSetting       1
    wMaxPacketSize       0009
    wMaxPacketSize       0009

2026-09-26T10:58:09.711803+02:00 n kernel: audit: type=1400 audit(1790413089.710:250): apparmor="STATUS" operation="profile_replace" info="same as current profile, skipping" profile="unconfined" name="snap.mesa-2404.hook.disconnect-plug-kernel-gpu-2404" pid=165986 comm="apparmor_parser"
usb-layer lines since the fault: 0
```

**Evidence window.** `2026-09-26T02:09:46.067797+02:00` — `2026-09-26T14:44:12+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-26T14:44:14+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `e90c9c57` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
