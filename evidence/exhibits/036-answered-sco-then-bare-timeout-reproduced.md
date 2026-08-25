# EX-036 — answered-sco-then-bare-timeout-reproduced

**Claim.** `EX-033`'s signature reproduced, seven days later, on a different peripheral and
a different kernel: `0x0428` **answered** in 74.9 ms, `evt 5` transparent air mode, both alt
probes then silence, and the fault arriving **2.152 s** later on the **bare**
`command tx timeout` with no opcode. `EX-033` measured 2.076 s.

**Relevance.** `EX-033` was `n = 1`, and its two load-bearing claims — that the controller
*answers* the legacy SCO setup, and that the command which dies is anonymous — rested on a
single observation. **They are now `n = 2`**, with an interval agreeing to 76 ms.

## Extraction method

Re-runnable as-is on the affected machine, while boot `c8342e9b` is retained:

```console
$ journalctl -k -b 0 --since '2026-08-25 17:08:08.5' --until '2026-08-25 17:08:11' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|hcon .* handle 0x0005|evt 5|Looking for Alt no|tx timeout'; journalctl -k -b 0 --since '2026-08-25 17:08:10' --no-pager | grep -cE 'usb 3-3|USB disconnect'
```

## Output

Verbatim, 7 line(s), exit status 0.

```
2026-08-25T17:08:08.550995+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-25T17:08:08.625863+02:00 n kernel: hci0: hcon 00000000a29f3bc5 handle 0x0005
2026-08-25T17:08:08.625984+02:00 n kernel: hci0 evt 5
2026-08-25T17:08:08.626011+02:00 n kernel: Looking for Alt no :6
2026-08-25T17:08:08.626037+02:00 n kernel: Looking for Alt no :3
2026-08-25T17:08:10.702854+02:00 n kernel: Bluetooth: hci0: command tx timeout
0
```

The trailing `0` is USB-layer lines since the fault: the controller stayed enumerated.

## The pair

| | `EX-033` | **this** |
|---|---|---|
| date | 2026-08-22 01:31 | 2026-08-25 17:08 |
| kernel | `7.0.0-29-generic` | `7.0.0-30-generic` |
| peer | Lenovo `thinkplus-GM2 pro` | Sennheiser `MOMENTUM 4` |
| `0x0428` answered | ✔ in 72.8 ms, handle `0x0004` | ✔ in **74.9 ms**, handle `0x0005` |
| `evt 5` — transparent air mode | ✔ | ✔ |
| `Looking for Alt no :6` then `:3`, then silence | ✔ | ✔ |
| what timed out | **bare**, no opcode | **bare**, no opcode |
| setup → fault | **2.076 s** | **2.152 s** |
| USB-layer lines after | 0 | 0 |

Two vendors, two kernels, two occasions, and the two intervals differ by **76 ms**.

## What this settles, and what it does not

**Settled: the controller answers `0x0428`.** For weeks `BT-1` was stated as "the SCO setup
is submitted and never answered". That statement is wrong, and it is now wrong twice, on
different hardware. A connection handle is allocated both times — something no timeout path
produces.

**Settled: the dying command is anonymous by construction.** The kernel prints the opcode
from `hdev->req_skb`; the bare form means that pointer was NULL, so the command that timed
out was not the one `hci_cmd_sync` was tracking. Twice, at nearly the same offset from a
successful setup.

⚠️ **That reframes the search for a "trigger opcode".** The spread this project kept
measuring — 4.1, 7.6, 16.2, 55.2, 155.8 s — was gathered by anchoring on whichever *named*
command happened to time out. Anchored instead on the answered setup, two instances agree
within 76 ms. The distribution may have been an artefact of measuring from the wrong event.
`n = 2` is not enough to claim that; it is enough to stop assuming the opposite.

**Not settled: what the anonymous command is.** Naming it needs either driver instrumentation
(`BL`-tracked, `§4.1` of the source-review brief) or an mgmt/btmon trace across the window.

## Two further attempts, and the difference is informative

```
17:08:27.977046  hci0 opcode 0x0428 plen 17   → no handle → 0x0406 tx timeout at +2.054 s
17:08:35.036075  hci0 opcode 0x0428 plen 17   → no handle → 0x0406 tx timeout at +2.035 s
```

Neither was answered — no `hcon … handle`, and the timeout names an opcode. So the
**answered-then-anonymous** shape belongs to the *first* setup against a healthy controller;
once wedged, later setups fail in the ordinary named way. Any future capture should
therefore anchor on the first `0x0428` of a window, not the last.

## Terminator

⚠️ **This window is censored and is not a duration measurement.** `bt-window` reports five
operator rfkill toggles after the fault — the operator attempting recovery, which is the
reasonable thing to do on a shared machine. It measures time-to-intervention.

## The patched daemon was running, and this is not about it

`bluetoothd` was the locally built binary carrying both `patches/bluez/` fixes (`EX-035`).
Across this event: **0 patch guards fired, 0 daemon crashes.** `BT-1` is the controller
fault and neither patch touches it. The patched daemon has now survived a controller wedge
without incident, which is worth recording and is not evidence for the patches.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-25T17:10:31+02:00` |
| kernel | `7.0.0-30-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME); peer `MOMENTUM 4` |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260825-171031-sco-answered-then-bare-timeout-second-instance` |
| confirms | `EX-033` |
