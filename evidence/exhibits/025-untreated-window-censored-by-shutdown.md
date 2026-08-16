# EX-025 — untreated-window-censored-by-shutdown

**Claim.** An untreated HCI-nonresponse window of 8883.7 s (2 h 28 m 4 s) with zero USB-layer lines and zero interventions, ended by an ordinary system shutdown rather than by anything touching the device.

**Relevance.** The four long untreated windows are the evidence that USB loss does not follow the fault unaided. Three were ended by an intervention — our btusb reload, an operator rfkill toggle, a deliberate reset — so each carried the objection that the ending was ours. This one was ended by a normal shutdown, which touches the controller no more than the passage of time does, making it the cleanest censoring type in the set.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b -1 --since '2026-08-15 16:55:59' --no-pager | grep -cE 'usb 3-3|xhci_hcd|USB disconnect'; journalctl -b -1 --since '2026-08-15 16:55:59' --no-pager | grep -cE 'deregistering interface driver btusb|Resetting usb device|reset (full|high|low)-speed USB device|intervening|blocked 1'; journalctl -b -1 -n 3 --no-pager -o short-iso | tail -3
```

## Output

Verbatim, 5 line(s), exit status 0.

```
0
0
2026-08-15T19:24:03+02:00 n systemd-journald[34149]: Received SIGTERM from PID 1 (systemd-shutdow).
2026-08-15T19:24:03+02:00 n dnsmasq[2554]: exiting on receipt of SIGTERM
2026-08-15T19:24:03+02:00 n systemd-journald[34149]: Journal stopped
```

## The window

```
16:55:59.333  command 0x0406 tx timeout      fault — controller stops answering HCI
              ┃
              ┃   8883.7 s  (2 h 28 m 4 s)
              ┃   0 USB-layer lines.  0 interventions.  nothing at all.
              ┃
19:24:03      Received SIGTERM from PID 1 (systemd-shutdown)
19:24:03      Journal stopped              ordinary shutdown
19:25:45      boot begins; 13d3:3503 enumerates normally
```

## The four untreated windows

| window | duration | ended by | is the ending ours? |
|---|---:|---|---|
| `EX-023` | 12107 s | deliberate `USBDEVFS_RESET` → collapse in 11.2 s | **yes** |
| **this one** | **8884 s** | **ordinary shutdown** | **no** |
| `EX-016` | 4332 s | `install.sh` reloading btusb | **yes** |
| `EX-021` | 1837 s | operator rfkill toggle → collapse in 12.8 s | **yes** |

Against fourteen earlier windows in `EX-018`, every one ended by a watchdog reset
within 29–121 s — the figure that was read for months as the fault's own timing
and was in fact the watchdog's reaction time.

## Reading

**This is the window with the fewest objections available to it.** The other
three each invite the same one: the ending was ours, so the absence of
progression only tells you what happens up to the moment we intervened. A
shutdown is different in kind. It does not reset the device, does not unbind the
driver, does not touch the bus — it stops asking questions. The controller was
still enumerated with a silent USB layer when the machine went down.

That does not make it uncensored. It is still a **lower bound**: 8883.7 s is
what the window reached, not what it would have reached. But the censoring
mechanism is unrelated to the device, which is the property the other three
lack.

**What the set now supports.** Four windows, 1837 s to 12107 s, no USB-layer
activity in any of them while untouched. Two deliberate resets, at 613 s and
12107 s of window age, both fatal within seconds to minutes. Fourteen prior
windows all ended by intervention before any USB event. Across all of it, **a
USB collapse has never once begun before something touched the controller.**

**What it does not support.** None of this proves the reset *causes* stage 2, and
none of it excludes spontaneous collapse at some interval longer than 3 h 22 m.
`n = 4` for untreated windows and `n = 2` for deliberate resets. The honest
statement is that the untreated trajectory is unmeasured beyond these bounds,
and that the 45–66 s figure is retired — not replaced.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-16T02:49:30+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `95d14e7a` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
