# EX-053 — alt1-death-12-third-headset-shure-aonic-50

**Claim.** Twelfth alt-1 death, 2026-09-26 02:09:46, kernel 7.0.0-34-generic, stock bluetooth.ko, and the first with a third headset model, the Shure AONIC 50 (the only connected device): SCO set up at 02:09:36.647, link up at 02:09:36.719 with 'Looking for Alt no :6' then ':3', then 7.3 s of transparent SCO on alt 1 (2434 packets in the 12 s window, 2432 of them 27-byte mSBC as 3x9) with no command in flight; the first command issued, 0x0406 Disconnect (reason 0x13) at 02:09:44.050, is never answered and times out at 02:09:46.068; setup to fault 9.421 s. sysfs, read live inside the untreated window, shows bAlternateSetting 1 / wMaxPacketSize 0009.

**Relevance.** Same signature on a third peripheral from a third vendor: the fault is not a property of one headset. Like EX-043, the stream runs for seconds without harm until the first command is issued.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ uname -r; cat /sys/module/bluetooth/srcversion; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot e90c9c57bebe4438ad3d4087f074eba0 --before 12 --after 3 2>&1 | head -8; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot e90c9c57bebe4438ad3d4087f074eba0 --before 12 --after 3 2>&1 | grep -E 'opcode 0x0428|evt 5|Looking for Alt|reason 0x13|Opcode 0x0406|tx timeout|setup → fault'; echo; /root/exp/qca9377-bt-hang/tools/bt-usbstate 2>&1 | grep -E '^bt-usbstate|interface 3-3:1.1|bAlternateSetting       1|wMaxPacketSize       0009'; echo; /root/exp/qca9377-bt-hang/tools/bt-window 2>&1 | head -10; echo; bluetoothctl devices Connected
```

## Output

Verbatim, 39 line(s), exit status 0.

> **Redaction notice.** MAC addresses, BSSIDs, UUIDs and IPv4
> addresses were replaced with stable placeholders
> (`AA:BB:CC:00:00:NN`, `<UUID-NN>`, `<IPV4-NN>`) before publication.
> The same real value always maps to the same placeholder, so
> cross-references within the output remain readable. Nothing
> else was altered. Re-running the command locally will show the
> real addresses in these positions.

```
7.0.0-34-generic
052335E5B69A055D6D15874

bt-fault-window — boot e90c9c57bebe4438ad3d4087f074eba0, anchored on 2026-09-26T02:09:46.067797+02:00
  window: 2026-09-26 02:09:34 … 2026-09-26 02:09:49  (−12s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)       2434   of which 27-byte mSBC: 2432
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  alt-1 transparent SCO (27-byte buffers as 3×9-byte packets) — the BT-1 condition.


    2026-09-26T02:09:36.646940+02:00 n kernel: hci0 opcode 0x0428 plen 17
    2026-09-26T02:09:36.718906+02:00 n kernel: hci0 evt 5
    2026-09-26T02:09:36.718950+02:00 n kernel: Looking for Alt no :6
    2026-09-26T02:09:36.718976+02:00 n kernel: Looking for Alt no :3
    2026-09-26T02:09:44.049893+02:00 n kernel: hci0: handle 0x06 reason 0x13
    2026-09-26T02:09:44.049956+02:00 n kernel: hci0: Opcode 0x0406
    2026-09-26T02:09:46.067797+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
  0x0428 setup → fault: 9.421 s

bt-usbstate — 3-3 at 2026-09-26T02:12:27+02:00
interface 3-3:1.1
  bAlternateSetting       1
    wMaxPacketSize       0009
    wMaxPacketSize       0009

HCI non-response window
  first timeout      2026-09-26T02:09:46.067797+02:00
  now                2026-09-26T02:12:28+02:00
  elapsed            161.932s
  command timeouts   6

  ✓ still enumerated  13d3:3503 is on the USB bus
  ✓ USB layer silent  no bus-level line since the fault
  ✓ no intervention  neither tooling nor operator has touched it


Device AA:BB:CC:00:00:01 Shure AONIC 50
```

**Evidence window.** `2026-09-26T02:09:36.646940+02:00` — `2026-09-26T02:12:28+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-26T02:12:28+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `e90c9c57` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `yes` |
