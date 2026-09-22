# EX-045 — alt1-death-8-original-config-with-counters

**Claim.** Eighth alt-1 death, 2026-09-22 15:50:47, under the ORIGINAL configuration (autosusp=Y, power=auto, experiment stamp since 09-17): 735 transparent-SCO packets on alt 1 (27-byte buffers as 3x9) in the 7 s window, then the first command issued (0x0406 Disconnect, reason 0x13) times out after 2.018 s; controller still enumerated with bAlternateSetting 1 / wMaxPacketSize 0009 read from sysfs 8.5 h later, untreated. This is the owed alt-1 capture with counters under the original configuration (BRIEF 9.5).

**Relevance.** Same signature as EX-033..043 (n=8): alt-1 transparent SCO, first command after link-up dies with HCI_CMD_TIMEOUT, dying command 0x0406 again; and it is the second death under stock power management, so the modified/original split is not the variable.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ tools/bt-fault-window 2>&1 | head -30; echo; tools/bt-usbstate 2>&1 | grep -E "^bt-usbstate|idVendor|idProduct|interface 3-3:1.1|bAlternateSetting       1|wMaxPacketSize       0009|runtime_status|control "; echo; tools/bt-window 2>&1 | head -9; echo; tools/bt-mode status 2>&1 | sed -n "3,6p"
```

## Output

Verbatim, 56 line(s), exit status 0.

```
bt-fault-window — boot 0, anchored on 2026-09-22T15:50:47.222950+02:00
  window: 2026-09-22 15:50:43 … 2026-09-22 15:50:50  (−4s / +3s)

  SCO packets in this window
    alt-1  (mtu 9)        735   of which 27-byte mSBC: 735
    wider  (mtu >9)         0   (CVSD — the healthy path)
    ⚠️  alt-1 transparent SCO (27-byte buffers as 3×9-byte packets) — the BT-1 condition.

  sequence
    2026-09-22T15:50:45.204786+02:00 n kernel: hcon 00000000a4bd82ae state BT_CONNECTED
    2026-09-22T15:50:45.204817+02:00 n kernel: hci0: handle 0x0f reason 0x13
    2026-09-22T15:50:45.204828+02:00 n kernel: hci0: 
    2026-09-22T15:50:45.204850+02:00 n kernel: hci0: entry 0000000050a33cc5
    2026-09-22T15:50:45.204860+02:00 n kernel: hci0: Opcode 0x0406
    2026-09-22T15:50:45.204879+02:00 n kernel: hci0: opcode 0x0406 plen 3
    2026-09-22T15:50:45.204890+02:00 n kernel: hci0: skb len 6
    2026-09-22T15:50:45.204908+02:00 n kernel: hci0: length 1
    2026-09-22T15:50:45.204938+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 1
    2026-09-22T15:50:45.204951+02:00 n kernel: hci0: skb 00000000e466ffa4
    2026-09-22T15:50:47.222823+02:00 n kernel: hci0: end: err -110
    2026-09-22T15:50:47.222950+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
    2026-09-22T15:50:47.223015+02:00 n kernel: hci0: err 0x6e
    2026-09-22T15:50:47.223040+02:00 n kernel: hci0: status 0x13
    2026-09-22T15:50:47.223066+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 0
    2026-09-22T15:50:47.223091+02:00 n kernel: hci0 hcon 00000000a4bd82ae handle 15
    2026-09-22T15:50:47.223117+02:00 n kernel: hci0: hcon 00000000a4bd82ae
    2026-09-22T15:50:47.238848+02:00 n kernel: hcon 00000000a4bd82ae
    2026-09-22T15:50:47.238984+02:00 n kernel: hci0 evt 6

    (735 line(s) filtered as repeated SCO/debug noise — --raw shows all 754)

bt-usbstate — 3-3 at 2026-09-23T00:22:35+02:00
  idVendor               13d3
  idProduct              3503
  runtime_status         active
  control                auto
interface 3-3:1.1
  bAlternateSetting       1
    wMaxPacketSize       0009
    wMaxPacketSize       0009
  Read from sysfs only — no control transfer was issued. Safe inside an

HCI non-response window
  first timeout      2026-09-22T15:50:47.222950+02:00
  now                2026-09-23T00:22:42+02:00
  elapsed            30714.777s
  command timeouts   58

  ✓ still enumerated  13d3:3503 is on the USB bus
  ✓ USB layer silent  no bus-level line since the fault
  ✓ no intervention  neither tooling nor operator has touched it

  recorded mode        experiment since 2026-09-17T13:40:59+02:00
  recovery watchdog    off
  periodic HCI probes  off
  btusb autosuspend    Y   (Ubuntu default Y)
```

**Evidence window.** `2026-09-17T13:40:59+02:00` — `2026-09-23T00:22:42+02:00`

## Provenance

| field | value |
|---|---|
| captured | `2026-09-23T00:22:42+02:00` |
| kernel | `7.0.0-31-generic` |
| boot id | `f759ae02` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
