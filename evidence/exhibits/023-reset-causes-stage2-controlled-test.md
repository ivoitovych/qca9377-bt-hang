# EX-023 — reset-causes-stage2-controlled-test

**Claim.** After 12107.4 s (3 h 21 m 47 s) of HCI non-response with zero USB-layer activity and no intervention of any kind, a single deliberate USBDEVFS_RESET produced USB disconnect in 11.15 s. This is the controlled version of the correlation seen in EX-016 and EX-021.

**Relevance.** Fourteen early windows were ended by a watchdog reset within 29-121 s and that latency was read as the fault's natural progression. Three long untreated windows since have shown no progression at all. This test supplies the missing arm: the same device, untouched for over three hours, collapses within seconds of being reset on purpose, with the reset timestamped by the operator rather than inferred.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -k -b 0 --since '2026-08-15 05:01:25' --until '2026-08-15 05:01:45' --no-pager -o short-iso-precise | grep -E 'reset full-speed|Timeout while waiting|not accepting address|USB disconnect'
```

## Output

Verbatim, 8 line(s), exit status 0.

```
2026-08-15T05:01:26.033858+02:00 n kernel: xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
2026-08-15T05:01:31.665858+02:00 n kernel: xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
2026-08-15T05:01:31.873834+02:00 n kernel: usb 3-3: device not accepting address 2, error -62
2026-08-15T05:01:31.985827+02:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-08-15T05:01:37.297822+02:00 n kernel: xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
2026-08-15T05:01:42.929809+02:00 n kernel: xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
2026-08-15T05:01:43.137820+02:00 n kernel: usb 3-3: device not accepting address 2, error -62
2026-08-15T05:01:43.138326+02:00 n kernel: usb 3-3: USB disconnect, device number 2
```

## The two intervals

| | |
|---|---:|
| Fault (first `0x0406 tx timeout`) | 2026-08-15T01:39:44.593804 |
| Untreated, USB-silent, no intervention | **12107.392 s** (3 h 21 m 47 s) |
| Deliberate `USBDEVFS_RESET` issued | 2026-08-15T05:01:31.985827 |
| Reset → `USB disconnect` | **11.152 s** |

## Why this is the controlled arm

`EX-018` showed fourteen windows, every one ended by an intervention within 29–121 s,
and that latency was read for months as the fault's own progression to USB loss.
`EX-016` (4331.99 s), `EX-021` (1836.5 s) and this window (12107.4 s) showed no
progression at all while untouched — but each was still ended by an intervention whose
timing the operator did not choose, so the correlation stayed a correlation.

This test supplies the missing arm. The device sat for **three hours and twenty-two
minutes** with not one USB-layer line. One reset was then issued **deliberately, at a
moment of the experimenter's choosing, with the timestamp recorded before the command**,
and the device was off the bus **11.15 s** later.

The ratio is the result: **12107 s of nothing, then 11 s to destruction.**

## The ioctl's error is part of the evidence

`USBDEVFS_RESET` returned `ENODEV`. The device node opened successfully — the device was
present when the call began — and the error was returned after the kernel had already
torn the device down. The failure code is the reset reporting the consequence of its own
action, not a failure to act. The kernel log confirms the ordering: the reset line at
05:01:31.985 precedes the disconnect at 05:01:43.138.

## What this establishes, stated narrowly

**Established.** On this device, in this state, a USB reset is followed by USB loss within
seconds, where three hours of no reset produced no USB loss. The operation used —
`USBDEVFS_RESET` — is the same one `usb_queue_reset_device()` performs, which is what
`btusb_qca_reset()` invokes on a device carrying the `BTUSB_QCA_ROME` quirk.

**Not established.** `n = 1` for the deliberate test. This does not show that a reset
issued *earlier* — seconds after the fault rather than hours — has the same effect;
`EX-004` records an early reset that did recover the controller, and that remains
unexplained by this result. Nor does it show the device would never have collapsed on its
own given longer.

## Consequence for BT-3

`BT-3` proposes adding `13d3:3503` to the btusb quirks table, which installs
`hdev->reset`. `hci_cmd_timeout()` calls that callback on the **first** timeout. This
exhibit shows the operation that callback performs destroying a device that had been
stable for over three hours.

That is not an argument that the patch is wrong — a reset at +0 s is a different
experiment from a reset at +3 h 22 m, and `EX-004` suggests the early case may differ.
It is an argument that **the direction of the patch's effect is unmeasured**, which is
what `docs/issues.md` now says, and that Build B must be scored on whether it reaches
stage 2 more often than untreated stock, not merely on whether it hangs.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-15T05:02:31+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `30bf5509` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
