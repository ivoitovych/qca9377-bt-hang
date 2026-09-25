# EX-047 — alt1-death-9-held-module-build

**Claim.** Ninth alt-1 death, 2026-09-24 03:24:59, on boot 20fbb9a2 (kernel 7.0.0-31-generic, self-built bluetooth.ko from updates/, srcversion 66D38200362CD82D3F68A9D per the original capture below): 717 SCO packets on alt 1 in the 7 s window, all 27-byte mSBC buffers as 3x9, then the first command issued, 0x0406 Disconnect (reason 0x13), is never answered and times out 2.053 s later.

**Relevance.** Same signature as EX-033..045, on a different bluetooth.ko build than every earlier death: the module build does not change this fault.

**Correction, 2026-09-26.** The original capture (kept verbatim below) ran its tools by relative path from a directory that is not the checkout, so only its first line — the live srcversion — carried evidence; the window and `sysfs` reads printed "No such file or directory". The window is re-captured here from the journal, by boot id so it stays re-runnable. The `sysfs` read taken 31 min after the fault cannot be re-taken and is no longer claimed.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl --list-boots --no-pager | grep -E '20fbb9a2afd44795a75bc95ed3f3a27e'; journalctl -k -b 20fbb9a2afd44795a75bc95ed3f3a27e --no-pager -o short-iso-precise --grep 'Linux version' | head -1 | sed -E 's/.*(Linux version [^ ]+).*/\1/'; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot 20fbb9a2afd44795a75bc95ed3f3a27e 2>&1 | head -8; echo; /root/exp/qca9377-bt-hang/tools/bt-fault-window --boot 20fbb9a2afd44795a75bc95ed3f3a27e 2>&1 | grep -E 'reason 0x13|Opcode 0x0406|tx timeout' | head -3
```

## Output

Verbatim, 15 line(s), exit status 0.

```
 -3 20fbb9a2afd44795a75bc95ed3f3a27e Thu 2026-09-24 01:18:58 CEST Thu 2026-09-24 08:58:57 CEST
Linux version 7.0.0-31-generic

bt-fault-window — boot 20fbb9a2afd44795a75bc95ed3f3a27e, anchored on 2026-09-24T03:24:59.199448+02:00
  window: 2026-09-24 03:24:55 … 2026-09-24 03:25:02  (−4s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)        717   of which 27-byte mSBC: 717
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  alt-1 transparent SCO (27-byte buffers as 3×9-byte packets) — the BT-1 condition.


    2026-09-24T03:24:57.146476+02:00 n kernel: hci0: handle 0x03 reason 0x13
    2026-09-24T03:24:57.146538+02:00 n kernel: hci0: Opcode 0x0406
    2026-09-24T03:24:59.199448+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
```

**Evidence window.** `2026-09-24T03:24:57.146476+02:00` — `2026-09-24T03:24:59.199448+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-26T01:42:18+02:00` |
| kernel | `7.0.0-34-generic` |
| boot id | `e90c9c57` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |

## Original capture, 2026-09-24 (kept verbatim)

```console
$ cat /sys/module/bluetooth/srcversion; echo; tools/bt-fault-window 2>&1 | head -30; echo; tools/bt-usbstate 2>&1 | grep -E "^bt-usbstate|interface 3-3:1.1|bAlternateSetting       1|wMaxPacketSize       0009"; echo; tools/bt-window 2>&1 | head -9
```

Verbatim, 6 line(s), exit status 0.

```
66D38200362CD82D3F68A9D

bash: line 1: tools/bt-fault-window: No such file or directory


bash: line 1: tools/bt-window: No such file or directory
```

| field | value |
|---|---|
| captured | `2026-09-24T03:56:42+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `20fbb9a2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
