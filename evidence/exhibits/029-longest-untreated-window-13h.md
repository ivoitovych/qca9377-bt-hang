# EX-029 — longest-untreated-window-13h

**Claim.** An HCI-nonresponse window of **47338.1 s — 13 h 8 m 58 s** — with **zero**
USB-layer lines and **zero** interventions across its whole length, ended only when the
machine was powered off. It is 3.9× the longest previously recorded untreated window.

**Relevance.** The single strongest observation this project has. `EX-023`'s 12107 s was
the ceiling, and it ended in a reset we issued; every other long window ended in something
we or the operator did. This one was not touched for over thirteen hours, and the reason
is mundane — nobody noticed the controller had died. The unattended interval is what
makes it evidence.

## Extraction method

Re-runnable as-is on the affected machine, while boot `7dd5d642` is retained:

```console
$ journalctl -k -b -1 --no-pager -o short-iso-precise | grep -E 'command 0x[0-9a-f]+ tx timeout' | head -1; journalctl -k -b -1 --since '2026-08-16 21:42:44' --no-pager | grep -cE 'usb 3-3|xhci_hcd|USB disconnect'; journalctl -b -1 --since '2026-08-16 21:42:44' --until '2026-08-17 10:51:43' --no-pager | grep -cE 'deregistering interface driver btusb|Resetting usb device|reset (full|high|low)-speed USB device|name hci[0-9]+ blocked 1'; journalctl -b -1 --since '2026-08-17 10:51:43' --no-pager -o short-iso | grep -E 'name hci0 blocked 1|plymouth-poweroff' | head -2
```

## Output

Verbatim, 5 line(s), exit status 0.

```
2026-08-16T21:42:44.918919+02:00 n kernel: Bluetooth: hci0: command 0x041f tx timeout
0
0
2026-08-17T10:51:43+02:00 n kernel: 000000008cd63972 name hci0 blocked 1
2026-08-17T10:51:56+02:00 n systemd[1]: Starting plymouth-poweroff.service - Show Plymouth Power Off Screen...
```

Line 2 is the count of USB-layer lines from the fault to the end of the boot: **zero**.
Line 3 is the count of interventions from the fault to the first shutdown action:
**zero**. Line 4 is that first shutdown action.

## The window

```
2026-08-16
21:41:49.739  hci0 opcode 0x0428 plen 17            SCO setup — the known trigger
21:42:42.858  Bluetooth: hci0: link tx timeout      a line kind new to this record
21:42:44.918  command 0x041f tx timeout             fault — HCI non-response begins
              ┃
              ┃   47338.1 s   (13 h 8 m 58 s)
              ┃   303 command timeouts
              ┃   0 USB-layer lines.  0 interventions.  nobody was watching.
              ┃
2026-08-17
10:51:43      name hci0 blocked 1                   shutdown begins
10:51:56      plymouth-poweroff.service             power off
11:17:37      boot begins after 25 min off; 13d3:3503 enumerates normally
```

## Every untreated window, in order

| window | duration | ended by | is the ending ours? |
|---|---:|---|---|
| **this one** | **47338 s** | **power-off after 13 h unattended** | see below |
| `EX-023` | 12107 s | deliberate `USBDEVFS_RESET` → collapse in 11.2 s | yes |
| `EX-025` | 8884 s | ordinary shutdown | no |
| `EX-016` | 4332 s | `install.sh` reloading btusb | yes |
| `EX-021` | 1837 s | operator rfkill toggle → collapse in 12.8 s | yes |

## The terminator was touched, and that is recorded rather than glossed

The 47338.1 s figure runs from the fault to the **first shutdown action**, and everything
inside it is clean. What happened *after* is not:

* `10:51:43` the shutdown's own rfkill block, which produced
  `Bluetooth: hci0: Error when powering off device on rfkill (-110)` — the controller
  could not answer, exactly as in `EX-026`.
* `10:51:56` our `bt-trial-auto` stop hook ran, and `bt-trial autostop` calls `hci_alive`,
  which issues `timeout 6 hciconfig hci0 name`. **The controller was probed by our own
  tooling at shutdown.** The trial closed at `10:52:18` recording
  `RESULT: failed | responds=no`, which is that probe's answer.

This is `BL-08` behaving exactly as predicted the night before, and it was accepted
knowingly: the operator declined the workaround because it depended on whoever shuts the
laptop down remembering to say so, and on a family machine that is not a control. The
right conclusion is not that this window is spoiled — the 13 hours before the shutdown are
untouched and that is the claim — but that **`autostop` must stop probing**, which is now
the first item of `BL-08`.

⚠️ **A shutdown-censored window on this machine can no longer be called untouched without
checking whether a trial was open.** `EX-025`'s terminator predates this hook's timeout
behaviour and appears clean; that should be verified directly before it is cited upstream.

## A useful negative, from the same shutdown

`Error when powering off device on rfkill (-110)` appears here and in `EX-026`. There it
was followed by an unblock, a USB reset and total collapse. **Here it was followed by
nothing** — no reset, no descriptor errors, no disconnect, and the controller enumerated
normally on the next boot. So the failed rfkill power-off is not by itself a route to
stage 2; in `EX-026` what followed the *unblock* was.

## Reading

**What this establishes.** The untreated trajectory extends to at least 13 h 8 m 58 s with
no USB-layer activity whatsoever. The retired "45–66 s to USB collapse" is now wrong by
three orders of magnitude, and the claim that has survived every observation survives this
one: **a USB collapse has never begun before something touched the controller.**

**What it does not establish.** It remains a **lower bound**. 47338.1 s is what the window
reached, not what it would have reached, and the censoring — a family needing the laptop —
is unrelated to the device but still censoring. `n = 5` untreated windows.

**The trigger interval is an outlier again.** `0x0428` at `21:41:49.739021` → first command
timeout at `21:42:44.918919` is **55.18 s**, against 4.1–16.2 s across the five
instrumented instances. With the 155.8 s of 2026-08-16 15:16 that is two long outliers in
two days, so either the interval has a second population or nearest-preceding attribution
is wrong for the long ones. Recorded, not resolved.

**A line kind still unexplained.** 283 occurrences of `Bluetooth: hci0: link tx timeout`,
first at `21:42:42.858918` — ahead of the first command timeout, and absent from every
earlier instance in this record.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-17T12:15:00+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `7dd5d642` (the window) / `e9399c8c` (capture) |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260817-004559-longest-untreated-window-20260816` |
