# EX-034 — reboot-from-stage1-failed-after-recovery-ladder

**Claim.** A hot reboot taken while the controller was in **stage 1** — on the bus, driver
bound, `hci0` present, zero USB-layer lines — failed to enumerate it, with the exact
signature `EX-027` recorded for a reboot from **stage 2**. The device had been through a
three-rung recovery ladder that produced *no USB-layer line at the time*.

**Relevance.** It refutes `EX-027`'s first row as a general rule, and it introduces a shape
this record did not have: **an intervention whose damage is invisible in the log until the
next enumeration.** The ladder looked harmless on every check available while it ran.

⚠️ **This exhibit corrects a statement made in this project's own commit `5350148`**, which
said the ladder "recovered nothing and **destroyed nothing**". The first half stands. The
second was premature — it was true of every observable at the time and false by the next
boot.

## Extraction method

Re-runnable as-is on the affected machine, while boots `56afa828` and `b8e9a9fb` are
retained:

```console
$ journalctl -b -1 --no-pager -o short-iso | grep -E 'Reached target (reboot|poweroff)' | tail -1; journalctl -k -b 0 --no-pager -o short-monotonic | grep -E 'usb 3-3|usb3-port3' | head -14
```

## Output

Verbatim, 15 line(s), exit status 0.

```
2026-08-22T11:39:16+02:00 n systemd[1]: Reached target reboot.target - System Reboot.
[    0.813072] n kernel: usb 3-3: new full-speed USB device number 2 using xhci_hcd
[   16.620615] n kernel: usb 3-3: device descriptor read/64, error -110
[   32.492676] n kernel: usb 3-3: device descriptor read/64, error -110
[   32.708581] n kernel: usb 3-3: new full-speed USB device number 3 using xhci_hcd
[   48.364668] n kernel: usb 3-3: device descriptor read/64, error -110
[   64.236655] n kernel: usb 3-3: device descriptor read/64, error -110
[   64.340912] n kernel: usb usb3-port3: attempt power cycle
[   64.719589] n kernel: usb 3-3: new full-speed USB device number 4 using xhci_hcd
[   75.596563] n kernel: usb 3-3: device not accepting address 4, error -62
[   75.596724] n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
[   75.708569] n kernel: usb 3-3: new full-speed USB device number 5 using xhci_hcd
[   86.860733] n kernel: usb 3-3: device not accepting address 5, error -62
[   86.860881] n kernel: usb 3-3: WARN: invalid context state for evaluate context command.
[   86.861023] n kernel: usb usb3-port3: unable to enumerate USB device
```

Current state: `/sys/bus/usb/devices/3-3` does not exist and `/sys/class/bluetooth/` is
empty.

## The state going in, which is the whole point

Immediately before the reboot, verified rather than assumed:

| check | value |
|---|---|
| `/sys/bus/usb/devices/3-3` | **present** |
| driver binding | **bound** — `3-3:1.0`, `3-3:1.1` under `/sys/bus/usb/drivers/btusb/` |
| `/sys/class/bluetooth/hci0` | **present** |
| USB-layer lines since the fault (35113 s) | **0** |
| USB-layer lines during the whole recovery ladder | **0** |
| `hci0` administrative state | DOWN, `BD Address 00:00:00:00:00:00` |

That is stage 1 by every definition this record uses. It is **not** stage 2: the device had
never left the bus.

## Against `EX-027`

`EX-027` paired two `reboot.target` transitions and concluded that the controller's state
going in was the variable:

| | `EX-027` row 1 | `EX-027` row 2 | **this** |
|---|---|---|---|
| target | `reboot.target` | `reboot.target` | `reboot.target` |
| state going in | stage 1 | stage 2 | **stage 1** |
| recovery ladder run first? | no | no | **yes** |
| next boot enumerates? | **yes**, `+1.107 s` | no, `unable to enumerate` at `+86.9 s` | **no**, `unable to enumerate` at `+86.9 s` |

**The terminator figure is the same to a tenth of a second** — 86.9 s in both failures,
which is usbcore's fixed retry schedule and says nothing about the device.

So "stage 1 survives a reboot" does not hold. The two stage-1 cases differ in exactly one
recorded respect: this one had a daemon restart, an `hciconfig hci0 down` with a failed
`up`, and a `modprobe -r btusb` / reload applied first.

## What the ladder did, and when it became visible

```
11:19:02  step 0  pre-state marked; window 35113 s untreated
11:19:1x  step 1  systemctl restart bluetooth      responds no; timeouts 22 → 30
11:19:3x  step 2  hciconfig hci0 down              succeeded
                  hciconfig hci0 up                Can't init device hci0: … (110)
11:20:37  step 3  usbcore: deregistering interface driver btusb
11:20:45          usbcore: registered new interface driver btusb
          →       re-bound to 3-3:1.0 and 3-3:1.1, hci0 recreated, responds no
          →       ZERO usb 3-3 lines throughout
11:39:16          reboot.target
11:41:11+0.8 s    usb 3-3: new full-speed USB device number 2
        +86.9 s   usb usb3-port3: unable to enumerate USB device
```

**Twenty minutes of silence between the last intervention and the first sign of harm**, and
the sign only appeared once the host tried to enumerate from scratch.

## Reading

**What this establishes.** A reboot is not a reliable recovery from stage 1. And an
intervention can leave the controller unable to enumerate while every contemporaneous
check — bus presence, driver binding, `hci0` existence, absence of USB-layer lines — reads
clean.

**What it does not establish.** *Which* rung did it, or whether the reboot itself was
required to expose it. Three interventions were applied in sequence and only the aggregate
was tested; `n = 1`. The `hciconfig up` that failed with `-110` is the most suspicious,
since `HCI_Reset` is the one rung that asks the controller to reinitialise, but that is a
hypothesis and the exhibit does not claim it.

**What it costs a previous claim.** `EX-027`'s framing — that the controller's stage
determines whether a reboot recovers it — was `n = 1` on each side and is now contradicted
on the stage-1 side. `EX-028`'s finding is untouched: that pair compared reboot against
power-off from the *same* stage-2 state, and power-off won.

**The general shape, which is new here.** Every safety check this project runs during an
intervention is a *contemporaneous* one. This is the first case where all of them passed
and the damage appeared later, at a boundary none of them watch. **"No USB-layer line
followed" is evidence about the moment, not about the device.**

**Recovery from here** is a full power-off, per `EX-028`. A further reboot is predicted not
to help and has not been attempted.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-22T11:43:00+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `b8e9a9fb` (capture) / `56afa828` (the ladder) |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260822-114303-hot-reboot-from-stage1-failed-to-enumerate` |
| supersedes | `EX-027`'s row-1 generalisation; corrects commit `5350148` |
