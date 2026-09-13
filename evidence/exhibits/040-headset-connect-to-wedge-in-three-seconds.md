# EX-040 — headset-connect-to-wedge-in-three-seconds

**Claim.** Fifth instance of the signature, and the **shortest and simplest path to it on
record**: an *incoming* HFP connection from the peripheral, a transparent SCO link 1.008 s
later, and the controller dead **2.140 s** after that. **3.148 s from connect to wedge, with
no interaction with the laptop at all.**

**Relevance.** ⚠️ **Every exhibit in this series has carried the same limitation — "no
reproducer, so no denominator."** This is the nearest thing yet to one. The machine had been
up 6 m 53 s and idle; nothing was clicked, no mode was switched, no audio was playing. The
headset connected and the controller was gone three seconds later.

## Extraction method

Re-runnable as-is while boot `197f351e` is retained:

```console
$ tools/bt-fault-window
$ journalctl -b 0 --since '2026-09-13 05:19:53.1' --until '2026-09-13 05:19:54.35' --no-pager -o short-iso-precise | grep -E 'ext_confirm|gateway state changed|AT\+|opcode 0x0428'
```

## Output

Verbatim, the two extractions joined.

```
  SCO packets in this window
    alt-1  (mtu 9)       1564   of which 27-byte mSBC: 1562
    wider  (mtu >9)         0   (CVSD — the healthy path)

    2026-09-13T05:19:54.204759+02:00 n kernel: hci0 opcode 0x0428 plen 17
    2026-09-13T05:19:54.296582+02:00 n kernel: hci0: hcon 0000000070544097 handle 0x0002
    2026-09-13T05:19:54.296694+02:00 n kernel: hci0 evt 5
    2026-09-13T05:19:54.296708+02:00 n kernel: Looking for Alt no :6
    2026-09-13T05:19:54.296738+02:00 n kernel: Looking for Alt no :3
    2026-09-13T05:19:54.330619+02:00 n kernel: hci0 cmd_cnt 1 cmd queued 1
    2026-09-13T05:19:56.344602+02:00 n kernel: Bluetooth: hci0: command tx timeout

  0x0428 setup → fault: 2.140 s

2026-09-13T05:19:53.195745 bluetoothd: src/profile.c:ext_confirm() incoming connect from <peer>
2026-09-13T05:19:53.195912 bluetoothd: src/profile.c:ext_connect() Hands-Free Voice gateway connected to <peer>
2026-09-13T05:19:53.196743 bluetoothd: Hands-Free Voice gateway state changed: connecting -> connected (0)
2026-09-13T05:19:53.464629 wireplumber: RFCOMM receive command but modem not available: AT+BTRH?
2026-09-13T05:19:54.204759 kernel: hci0 opcode 0x0428 plen 17
```

## The timeline, which is the point

```
05:13:03      boot
05:13:16.843  HFP gateway: unavailable → disconnected      nothing connected
              ┃
              ┃   6 m 53 s idle — machine untouched
              ┃
05:19:53.195  ext_confirm() INCOMING connect from the peer  ← the headset initiates
05:19:53.196  HFP gateway: connecting → connected           (+1 ms)
05:19:53.464  wireplumber: RFCOMM AT+BTRH?  modem not available
05:19:53.500  AVDTP incoming connect
05:19:54.204  0x0428 Setup Synchronous Connection           (+1.008 s)
05:19:54.296  answered, handle 0x0002, evt 5, :6 → :3       (+91.8 ms)
05:19:54.330  a command is queued                           (+34 ms after link-up)
05:19:56.344  command tx timeout — BARE                     (+2.140 s from setup)
              ┃
              └─ 3.148 s from connect to dead controller
```

**`ext_confirm() incoming connect`** is the load-bearing line: the *peripheral* opened the
connection. The laptop was not touched. `AT+BTRH?` is Response-and-Hold — the headset asking
about a held call — and `wireplumber` answers that no modem is available, which is the
ordinary state of a laptop with no telephony.

## The signature, `n = 5`

| | `EX-033` | `EX-036` | `EX-037` | `EX-038` | **this** |
|---|---|---|---|---|---|
| date | 08-22 | 08-25 | 09-01 | 09-13 00:54 | **09-13 05:19** |
| kernel | `-29` | `-30` | `-30` | `-31` | **`-31`** |
| `0x0428` answered | +72.8 ms | +74.9 ms | +88.6 ms | +135.9 ms | **+91.8 ms** |
| `evt 5`, `:6` → `:3` | ✔ | ✔ | ✔ | ✔ | ✔ |
| 27-byte frames on `mtu 9` | 835 | 87 | 680 | 682 | **1562**¹ |
| what timed out | bare | bare | bare | bare | **bare** |
| dying cmd queued after link-up | 36 ms | 279 ms | 39 ms | 35 ms | **34 ms** |
| setup → fault | 2.076 s | 2.152 s | 2.151 s | 2.191 s | **2.140 s** |
| alt 1 read from sysfs | — | — | ✔ | ✔ | ✔ |

¹ window-scoped (−4s/+3s) rather than link-up-to-fault; the tool's window opens before the
setup. The comparable figure is of the same order as `EX-037`/`EX-038`.

**Five occasions, three kernels. The setup-to-fault interval spans 115 ms; the dying command
is queued 34–39 ms after link-up in four of the five** (`EX-036`'s 279 ms is the outlier, and
it is also the only one where the log names the command: `0x0406 Disconnect`).

Third sysfs confirmation of the endpoint: `bAlternateSetting 1`, `wMaxPacketSize 0009`.

## ⚠️ What this is NOT: a one-line reproducer

Two different *entry paths* reach the same fatal sequence, and this exhibit only simplifies
one of them.

- **This instance**: no HFP connection existed; the peer connected and SCO followed in 1 s.
- **`EX-038`**, 4½ hours earlier: HFP was **already connected**; no `ext_confirm` appears in
  the minute before, and the SCO setup arose mid-session.

So "connect the headset and it dies" is **not** established as the general rule — it is the
shortest recorded path. What is invariant across all five is everything from `0x0428` onward.
A reproduction attempt should try the connect path first because it is cheapest, and must not
report a failure to reproduce as evidence the fault needs more.

## Terminator

```
first timeout   2026-09-13T05:19:56.344602+02:00
checked         2026-09-13T05:50:13+02:00     elapsed 1816.7 s (30 m)
interventions   0        neither tooling nor operator
USB-layer lines 0        ✓ bus silent
```

Clean, like `EX-038`. ⚠️ **Two wedges in one calendar day on the same kernel**, the machine
having been power cycled between them at 05:13 — which is also the first time the record has
an *immediate* post-recovery relapse.

## The patched daemon

Running (`/usr/local/libexec/bluetooth/bluetoothd`, PID 2804). **Guards fired 0, zero daemon
crashes this boot.** `BT-1` has now occurred **four times** with the patches installed.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-13T05:50:35+02:00` |
| kernel | `7.0.0-31-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| boot id | `197f351e` — started 2026-09-13 05:13:03 |
| treatment | `autosusp=N, power=on, wd=off, probes=off` |
| exit status | `0` |
| redacted | `yes` — peer address replaced in the quoted userspace lines |
| session | `evidence/sessions/20260913-055035-alt1-wedge-fifth-instance-7min-after-boot` |
| confirms | `EX-033`, `EX-036`, `EX-037`, `EX-038` |
