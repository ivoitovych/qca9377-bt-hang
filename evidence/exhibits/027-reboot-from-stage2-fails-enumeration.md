# EX-027 — reboot-from-stage2-fails-enumeration

**Claim.** Two `reboot.target` transitions three hours apart, on the same machine and the
same kernel, with opposite outcomes. The one taken while the controller was in stage 1
(enumerated, HCI silent) brought it back in 1.107 s. The one taken while it was in stage 2
(off the bus) did not bring it back at all: the port detects a device, every descriptor
read times out, and usbcore gives up with `unable to enumerate USB device` after 86.9 s.

**Relevance.** The wedge survives a host reboot. Enumeration is the bus asking a device
who it is, below btusb, below the HCI layer, below anything this project or the driver
does — and the device could not answer it after a full kernel restart. That places the
failed state in the controller itself rather than in host or driver state, and it is the
first time the record can separate the two.

**And it corrects the framing this exhibit was opened under.** The transition was
described as "a reboot, not a power off then on", inviting the reading that warm versus
cold is what mattered. The journal does not support that: **both** transitions are
recorded as `reboot.target`. What differed is the controller's state going in.

## Extraction method

Re-runnable as-is on the affected machine, while boots `7e63226d`, `60ddb417` and
`ea26d5d0` are retained:

```console
$ journalctl -b -2 --no-pager -o short-iso | grep -E 'Reached target reboot|Reached target poweroff' | tail -1; journalctl -k -b -1 --no-pager -o short-monotonic | grep -E 'New USB device found, idVendor=13d3|unable to enumerate' | head -2; echo '---'; journalctl -b -1 --no-pager -o short-iso | grep -E 'Reached target reboot|Reached target poweroff' | tail -1; journalctl -k -b 0 --no-pager -o short-monotonic | grep -E 'New USB device found, idVendor=13d3|unable to enumerate' | head -2
```

## Output

Verbatim, 5 line(s), exit status 0.

```
2026-08-16T15:29:59+02:00 n systemd[1]: Reached target reboot.target - System Reboot.
[    1.106823] n kernel: usb 3-3: New USB device found, idVendor=13d3, idProduct=3503, bcdDevice= 0.01
[  624.004282] n kernel: usb usb3-port3: unable to enumerate USB device
---
2026-08-16T18:46:06+02:00 n systemd[1]: Reached target reboot.target - System Reboot.
[   86.861877] n kernel: usb usb3-port3: unable to enumerate USB device
```

Boot `60ddb417` appears on both sides because it did both: it enumerated the controller at
`+1.107 s`, and 624 s later — after the rfkill sequence of `EX-026` — it could no longer
enumerate it.

## The pair

| | reboot at 15:29:59 | reboot at 18:46:06 |
|---|---|---|
| systemd target | `reboot.target` | `reboot.target` |
| controller state going in | **stage 1** — enumerated on the bus, HCI silent since 15:16:11 | **stage 2** — off the bus since 15:39:40 |
| USB disconnect before the reboot? | no — `usb 3-3` has no disconnect or reset line in that whole boot | yes, `USB disconnect, device number 2` |
| gap to next boot | 46 s | 116 s |
| next boot enumerates `13d3:3503`? | **yes**, at `+1.107 s` | **no** |
| terminator | — | `unable to enumerate USB device` at `+86.9 s` |

## What the port actually saw on the failed boot

Not silence. The device is electrically present and the port detects it four times over;
what fails is every attempt to talk to it.

```
[    0.971151]  usb 3-3: new full-speed USB device number 2 using xhci_hcd
[   16.621634]  usb 3-3: device descriptor read/64, error -110
[   32.493686]  usb 3-3: device descriptor read/64, error -110
[   32.709627]  usb 3-3: new full-speed USB device number 3 using xhci_hcd
[   48.365657]  usb 3-3: device descriptor read/64, error -110
[   64.237661]  usb 3-3: device descriptor read/64, error -110
[   64.720772]  usb 3-3: new full-speed USB device number 4 using xhci_hcd
[   69.757579]  xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
[   75.389611]  xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
[   75.597583]  usb 3-3: device not accepting address 4, error -62
[   75.597732]  usb 3-3: WARN: invalid context state for evaluate context command.
[   75.709746]  usb 3-3: new full-speed USB device number 5 using xhci_hcd
[   81.021644]  xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
[   86.653690]  xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
[   86.861582]  usb 3-3: device not accepting address 5, error -62
[   86.861738]  usb 3-3: WARN: invalid context state for evaluate context command.
[   86.861877]  usb usb3-port3: unable to enumerate USB device
```

`-110` is `ETIMEDOUT` and `-62` is `ETIME`. The failure escalates: the first two addresses
fail at the descriptor read, the last two fail earlier still, at `setup device` — the xHCI
controller cannot even complete address assignment.

Current state, same boot: `/sys/bus/usb/devices/3-3` does not exist,
`/sys/class/bluetooth/` is empty, and `rfkill list` reports only `phy0: Wireless LAN`.

## Reading

**Where this locates the fault.** A kernel restart discards every piece of host-side state
there is: the driver is reloaded, the HCI device is destroyed and recreated, xHCI is
re-initialised, the port is re-powered as far as the host controller can re-power it. None
of it helped. The device answered the electrical detection and nothing above it. Whatever
is wedged is on the device's side of the wire and it persists across the host's entire
lifecycle.

**Why this is worth more than the stage-1 comparison alone.** Individually, "it came back"
and "it did not" are two observations. Paired, with the same target, the same machine, the
same kernel and three hours between them, the controller's state going in is the only
variable the journal shows differing — and it is the variable the whole two-stage account
was built to describe.

**What it does not establish.** Neither transition is a logged power removal, so this pair
says nothing about whether cutting power recovers the device. The one instance in the
record where power was removed after a collapse is `EX-022`, where the controller
enumerated normally on the following boot — but the power-button hold there is the
operator's account with no supporting log line, and only the enumeration afterwards is
evidenced. **The reboot/power-off question is therefore still open**, and this exhibit
does not close it in either direction.

> **Closed 11 minutes later by `EX-028`.** A `poweroff.target` transition at 18:57:34,
> from this same stage-2 state, brought the controller back at `+1.020 s`. The terminator
> is a journal line rather than an account, so the question above is now answered: power
> removal clears the wedge, a kernel restart does not. This paragraph is left as written
> rather than edited, because what it was honest to claim at the time is part of the
> record.

**What is not claimed.** That a reboot from stage 1 *reliably* recovers the controller.
`n = 1` on each side of the pair. What is claimed is narrower and is what the lines
support: on this occasion the same command produced opposite outcomes, and the recorded
difference was the controller's state.

**Relation to `EX-022`.** That exhibit describes the *machine* failing to boot after a
collapse — 245 s with no journal at all. This one is not that: the machine booted normally
in 116 s and journald ran throughout. The two are separate consequences of stage 2 and
should not be cited for each other. `/sys/fs/pstore` is empty here, as it was there.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-16T18:55:00+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `ea26d5d0` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260816-185255-reboot-from-collapse-fails-enumeration-20260816` |
| precedes | `EX-026` supplies the stage-2 entry this exhibit reboots out of |
