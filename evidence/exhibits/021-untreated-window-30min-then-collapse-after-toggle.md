# EX-021 — untreated-window-30min-then-collapse-after-toggle

**Claim.** With no intervention of any kind, the controller stayed enumerated with a completely silent USB layer for 1836.5 s (30 m 36 s) after it stopped answering HCI. The USB collapse began 12.8 s after the operator's rfkill power-off attempt, and not before.

**Relevance.** Fourteen prior windows were all ended by an intervention before any USB event, so none could distinguish 'the fault progresses' from 'our action progresses it'. This one has 30 minutes of nothing followed by a collapse seconds after the first thing that touched it. Censored by the operator at 31 minutes, not by a watchdog at 45-66 s.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b 0 --since '2026-08-14 20:32:10' --until '2026-08-14 21:04:00' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|command( 0x[0-9a-f]+)? tx timeout|blocked 1|rfkill|usb 3-3' | head -12
```

## Output

Verbatim, 12 line(s), exit status 0.

```
2026-08-14T20:32:14.329557+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-14T20:32:21.903521+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:40.301451+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-14T20:32:42.319405+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:51.023359+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:53.071532+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:55.119356+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:57.167406+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:32:59.215361+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:33:01.263502+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T20:33:03.311361+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-14T21:02:57.615386+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
```

## The window, and what ended it

```
20:32:14.329  hci0 opcode 0x0428 plen 17          operator switched A2DP -> HFP
20:32:21.903  command 0x0406 tx timeout           controller stops answering
              ┃
              ┃   30 m 36 s   no USB-layer line. no intervention. nothing.
              ┃
21:02:58.369  USER opened the Bluetooth settings panel
21:03:23      name hci0 blocked 1                 rfkill soft block (toggle OFF)
21:03:26      Error when powering off device on rfkill (-110)
              ┃   12.8 s
21:03:35.809  usb 3-3: reset full-speed USB device   FIRST USB event of the window
21:03:51      usb 3-3: device descriptor read/64, error -110
21:04:50      usb 3-3: device not accepting address 2, error -62
              device gone from the bus
```

| | |
|---|---:|
| SCO setup → first timeout | **7.574 s** |
| Fault → first operator action | **1836.465 s** (30 m 36 s) |
| Fault → first USB-layer line | **1873.906 s** (31 m 14 s) |
| rfkill block → first USB reset | **12.809 s** |
| HCI command timeouts | 17 |

## Reading

**The trigger is operator-attributable and log-confirmed.** The operator reports
switching the headset from A2DP to hands-free; the journal shows `0x0428` —
Setup Synchronous Connection — at that moment, and the controller failing to
answer the teardown 7.6 s later. This is the same signature as `EX-016`
(`0x0428` → `0x0406 tx timeout` in 13.7 s). Two independent instances, one path.

**The 30-minute silence is the result.** Every one of the fourteen windows in
`EX-018` was ended by an intervention or a shutdown before any USB event, so
none could separate *the fault progresses* from *our action progresses it*.
This window has half an hour of nothing — no reset, no unload, no watchdog, no
probe, not one bus-level line — and then a collapse beginning **12.8 s after the
first thing that touched the device**.

**It is still censored, and by the operator.** This is not the uncensored
measurement. It is a **lower bound of 30 m 36 s** on untreated survival, ended
by an rfkill power-off attempt at a moment of the operator's choosing. What it
retires is the idea that 45–66 s was the fault's natural trajectory: that figure
is now 24× smaller than an untreated window that showed no progression at all.

**On causation, stated narrowly.** The reset at 21:03:35 carries no origin in
the log. `bt-stage2` classifies it `unknown-reset` — correctly. It followed the
rfkill attempt by 12.8 s; nothing in the record says it was *caused* by it. What
can be said is that in fifteen windows, a USB collapse has never once begun
before something touched the controller.

## A defect this observation exposed in our own instrument

`bt-window`, written during this window to report it, printed `✓ no
intervention` at 21:05 — after the toggle, after the collapse. Its intervention
scan matched watchdog markers, btusb unloads and USB resets, and **not rfkill or
operator actions**. A window that had just been intervened upon read as clean.

Fixed the same evening: the scan now counts tooling and operator interventions
separately and names which occurred. The failure is recorded here because it is
the same class the project keeps finding — a check whose silence is read as a
finding — and because it happened while the observation it describes was running.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-14T21:14:47+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `9d973714` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
