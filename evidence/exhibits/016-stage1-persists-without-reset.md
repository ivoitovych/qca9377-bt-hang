# EX-016 — stage1-persists-without-reset

**Claim.** With no watchdog reset, the controller remained enumerated and USB-error-free for 4331.99 s (1 h 12 m) after it stopped answering HCI. The observation was ended by the operator unloading btusb, not by the device leaving the bus.

**Relevance.** Every previously documented stage-1 to stage-2 progression (45-66 s) had one of our USB resets in between. This is the first window with none, and it shows no progression at all - so the 45-66 s figure may measure our recovery attempt rather than the fault's natural trajectory. n=1 and right-censored.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k --since '2026-08-13 05:14:30' --until '2026-08-13 06:26:43' --no-pager -o short-iso-precise | grep -E 'usb 3-3|xhci_hcd|USB disconnect|deregistering interface driver btusb'
```

## Output

Verbatim, 1 line(s), exit status 0.

```
2026-08-13T06:26:42.447916+02:00 n kernel: usbcore: deregistering interface driver btusb
```

## How the observation ended

One line in seventy-two minutes, and it is ours. `install.sh --apply` was run to
deploy a tooling fix; it reloads `btusb`, and the driver unload at 06:26:42 is
that. Everything after it — `reset full-speed USB device`, four `device
descriptor read/64, error -110`, `device not accepting address 2, error -62`,
`USB disconnect` at 06:28:13 — followed our intervention and says nothing about
what the device would have done on its own.

So this is a **right-censored** observation: stage 2 had not been reached at
4331.99 s, and the true survival time is unknown and longer. It is recorded that
way rather than as "survived 72 minutes", because the boot did not end on the
controller's terms.

Two things follow.

**On the finding.** The 45–66 s stage-1 durations in the earlier exhibits were
all measured across one of our USB resets. This window had none and showed no
progression at all. The hypothesis is that the reset — not the fault — drives
the device off the bus. n=1, censored; it needs a boot left alone until stage 2
arrives or the operator stops.

**On the instrument.** `install.sh` already refuses to run in experiment mode,
and the refusal was overridden with `BT_FORCE_INSTALL=1` on the reasoning that
the tooling change was passive. It was — but the *installer* is not: reloading
btusb resets the very device under observation. The force path now warns that it
will do so. Passive tools can still be delivered by an active mechanism, and the
mode check was guarding the wrong half.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-13T06:29:14+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `e3f66b3e` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
