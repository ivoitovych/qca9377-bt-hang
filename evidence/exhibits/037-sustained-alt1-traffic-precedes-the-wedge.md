# EX-037 — sustained-alt1-traffic-precedes-the-wedge

**Claim.** The controller wedged for a third time on the `EX-033`/`EX-036` signature, and
this time the **condition** was measured rather than inferred: **680 × `len 27 mtu 9`** —
27-byte mSBC frames pushed into the 9-byte alt-1 isochronous endpoint — in the **2.06 s**
between the transparent SCO link coming up and the bare `command tx timeout`.

**Relevance.** ⚠️ **This is a prediction that was made before the data existed.** On
2026-09-01, after a session in which the same test *survived*, `bt-snapshot` gained a
counter splitting SCO traffic by endpoint width, on the stated hypothesis that alt-1
traffic — not SCO setups, not alt probes — is what kills this controller. The next
occurrence is this one, and the counter reads what the hypothesis required.

| | `len 27 mtu 9` before the fault | outcome |
|---|---|---|
| `EX-033` — 2026-08-22 | 835 | **dead** |
| `EX-036` — 2026-08-25 | 87 | **dead** |
| 2026-09-01 daytime — 3 transparent links | **0** | **alive** |
| **this** — 2026-09-01 23:24 | **680** | **dead** |

The surviving session established the transparent link three times and reached the alt-1
endpoint each time, carrying **eight** `len 90 mtu 9` packets before collapsing back to
CVSD. Every death has hundreds of 27-byte frames; the survival has none.

## Extraction method

Re-runnable as-is on the affected machine, while boot `afd71c7b` is retained:

```console
$ journalctl -k -b 0 --since '2026-09-01 23:24:08.5' --until '2026-09-01 23:24:10.7' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|handle 0x0016|evt 5|Looking for Alt no|tx timeout'; journalctl -k -b 0 --since '2026-09-01 23:24:08.59' --until '2026-09-01 23:24:10.66' --no-pager | grep -c 'len 27 mtu 9'
```

## Output

Verbatim, 7 line(s), exit status 0.

```
2026-09-01T23:24:08.502939+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-09-01T23:24:08.591506+02:00 n kernel: hci0: hcon 000000003f1efcf0 handle 0x0016
2026-09-01T23:24:08.591592+02:00 n kernel: hci0 evt 5
2026-09-01T23:24:08.591615+02:00 n kernel: Looking for Alt no :6
2026-09-01T23:24:08.591634+02:00 n kernel: Looking for Alt no :3
2026-09-01T23:24:10.653478+02:00 n kernel: Bluetooth: hci0: command tx timeout
680
```

## The signature, now `n = 3`

| | `EX-033` | `EX-036` | **this** |
|---|---|---|---|
| date | 08-22 01:31 | 08-25 17:08 | **09-01 23:24** |
| kernel | `-29` | `-30` | `-30` |
| `0x0428` answered | ✔ +72.8 ms | ✔ +74.9 ms | ✔ **+88.6 ms**, handle `0x0016` |
| `evt 5` transparent | ✔ | ✔ | ✔ |
| `:6` then `:3` | ✔ | ✔ | ✔ |
| what timed out | bare | bare | **bare** |
| setup → fault | 2.076 s | 2.152 s | **2.151 s** |

Three occasions, two kernels, and the setup-to-fault interval spans **76 ms**.

## What is new here, beyond a third instance

**The condition is measured.** `EX-033` and `EX-036` recorded that the alt-1 path was
entered. Neither recorded how much traffic crossed it, so neither could distinguish
*entering* the path from *using* it. The 2026-09-01 survival forced that distinction:
the path was entered three times and the controller lived, because the stream collapsed
to CVSD before anything sustained.

⚠️ **And it corrects those two exhibits.** Both say the alt probes were followed by
"silence", and that the absence of a `:1` line was the signature. **That was an artefact
of their own grep** — the extraction pattern did not include `len`/`mtu` lines. SCO data
was flowing in both. Corrections are filed against each.

**The dying command is 39 ms after link-up.** A command was queued at `23:24:08.630601`
and the timeout fired `2.023 s` later, which is `HCI_CMD_TIMEOUT`. In `EX-033` the
equivalent command was queued 36 ms after link-up. In `EX-036` it is named outright —
`0x0406 Disconnect, handle 0x05, reason 0x13` at +279 ms. So the command that dies is
issued *while the alt-1 stream is running*, and the controller never answers it.

**The wedge is below HCI.** Two USB-layer lines since the fault, both a control transfer
timing out:

```
23:24:46.621481  usb 3-3: usbfs: USBDEVFS_CONTROL failed cmd tcpdump rqt 128 rq 6 len 18 ret -110
23:24:51.741482  usb 3-3: usbfs: USBDEVFS_CONTROL failed cmd tcpdump rqt 128 rq 6 len 9 ret -110
```

`-110` is `ETIMEDOUT`, on a **standard GET_DESCRIPTOR** request. The device is enumerated
and is not answering *USB control transfers* — so this is not an HCI-layer stall with a
live device underneath. (Both lines are our own tracing reaching for the descriptor; they
are a probe result, not a spontaneous USB event.)

**The stack keeps streaming into a dead controller.** 688 alt-1 packets before the first
timeout, **93,662 after** — the isochronous stream is never stopped by the failure.

## Terminator — and this one is clean

⚠️ Read this before using the duration. `bt-window` reports **no intervention**: neither
the tooling nor the operator has touched Bluetooth since the fault.

```
first timeout   2026-09-01T23:24:10.653478+02:00
still wedged    2026-09-02T00:30 — 66+ min, controller `responds no`, still on the bus
interventions   0
```

**This is an uncensored window**, unlike `EX-036` (5 operator rfkill toggles). It is the
duration measurement the record has been short of.

## The patched daemon, again, and again not the subject

`bluetoothd` is the local build carrying both `patches/bluez/` fixes. **Patch guards fired
0; zero daemon crashes.** As in `EX-036`, `BT-1` occurred with the patches in place, which
is the standing reason they cannot be credited for the 09-01 survival either.

## What this does not establish

**Not a mechanism.** That sustained alt-1 traffic precedes every recorded death and no
recorded survival is a strong correlation across `n = 3` deaths and one survival. It does
not show *how* the traffic wedges the controller — whether the isochronous endpoint
mismatch corrupts firmware state, exhausts a buffer, or something else. Naming that needs
the driver instrumentation already tracked in the source-review brief.

**Not a controlled comparison.** The survival was not arranged; the peripheral fell back to
CVSD on its own. Nobody has yet made this controller take the alt-1 path *and* forced the
stream to sustain, or blocked alt-1 and shown survival under otherwise identical use.

~~**And the fallback is still not directly observed.**~~ **It now is.** While the wedge was
still open, `sysfs` was read — no control transfer, no probe, nothing on the wire:

```console
$ tools/bt-usbstate
  bInterfaceNumber       01
  bAlternateSetting       1
  ep_03  type Isoc  wMaxPacketSize 0009  bInterval 01
  ep_83  type Isoc  wMaxPacketSize 0009  bInterval 01
```

**The SCO interface is on alternate setting 1 with 9-byte isochronous endpoints.** Not
inferred from the `:6`/`:3` probes, not inferred from btusb's `mtu 9` — read from the
kernel's own record of the interface. That is exactly the state
`BTUSB_USE_ALT1_FOR_WBS` selects, and exactly what a 27-byte mSBC frame does not fit into.

⚠️ **A reboot destroys this and the journal does not carry it.** Every previous wedge in
this record was rebooted away before anyone looked. `tools/bt-usbstate` exists so the next
one is not.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-02T00:29:55+02:00` |
| kernel | `7.0.0-30-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| boot id | `afd71c7b` |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260902-002955-alt1-sustained-traffic-then-wedge` |
| confirms | `EX-033`, `EX-036` |
| corrects | `EX-033`, `EX-036` — the "silence" claim |
