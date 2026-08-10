# Session: first real hang with full instrumentation

**When:** 2026-08-10 07:24:45 – 07:26:48 CEST
**Kernel:** 7.0.0-28-generic
**Trigger:** manual — manipulating a headset (connect/disconnect cycles)
**Outcome:** controller reached stage 2. **The watchdog fired correctly and the
USB reset did not recover it.**

---

## Why this session matters

This is the first hang captured with the watchdog armed, verbose logging on, and an HCI
trace running. It tests the one claim the kernel patch rests on:

> a USB reset during stage 1 recovers the controller

**It does not support that claim.** See "What this means for the patch" below.

---

## Timeline

| Time | Event | Δ from first timeout |
|---|---|---|
| 07:24:45.27 | first `hci0: command tx timeout` | 0 s |
| 07:25:05.59 | watchdog: 3/3 in window → **intervening** | **+20.3 s** |
| 07:25:23 | kernel: `usb 3-3: reset full-speed USB device number 2` | +38 s |
| 07:25:38.37 | `usb 3-3: device descriptor read/64, error -110` | **+53 s** |
| 07:26:37 | `device not accepting address 2, error -62` | +112 s |
| 07:26:48.61 | `usb 3-3: USB disconnect` — off the bus | +123 s |
| 07:26:48.69 | watchdog: `USBDEVFS_RESET failed` | +123 s |

The watchdog behaved exactly as designed: it detected the stall in **20 seconds** and
intervened **18 seconds before** the first USB-level failure. It was not too slow.

## What the HCI capture shows

From `bt-20260810-072446.btsnoop` (377 KB, begins 1 s after the first timeout):

```
< SCO Data TX: Handle 3 flags 0x00 dlen 24    ×hundreds
@ MGMT Event: Command Complete — Start Discovery (0x0023)
      Status: Authentication Failed (0x05)
< HCI Command: Disconnect (0x01|0x0006) Handle 3
      Reason: Remote User Terminated Connection (0x13)
@ MGMT Command: Set Powered — Powered: Disabled (0x00)
```

Three things this adds to what was known:

1. **The stream was SCO, not A2DP.** Hundreds of `SCO Data TX` packets — that is
   HFP voice audio, not music. The original logged instance was AVDTP/A2DP. The common
   factor is an **active audio stream being torn down**, not A2DP specifically.
2. **A discovery attempt collided with it**, returning `Authentication Failed (0x05)` —
   the same status seen in the original logs (`Failed to set mode: Authentication
   Failed (0x05)`). That error appears to be a *symptom* of the already-stalling
   controller rather than a genuine auth problem.
3. **`Set Powered: Disabled` followed the disconnect** — the adapter was being powered
   down while SCO traffic was still in flight.

## Corrections to earlier assumptions

| Assumption | This session |
|---|---|
| Stage 1 lasts ~6 hours | **~53 seconds** here (first timeout → USB failure) |
| Trigger is mid-stream A2DP teardown | SCO/HFP also triggers it |
| A USB reset during stage 1 recovers the chip | **Not supported — the reset failed** |

The 6-hour figure came from an instance where *nothing tried to reset the controller*.
It measured how long the chip stayed enumerated while idle, not how long it remains
recoverable. Those are different things, and conflating them was a mistake.

## What this means for the patch ⚠️

`btusb_qca_cmd_timeout()` calls `usb_queue_reset_device()`. The watchdog issued
`USBDEVFS_RESET` — the same operation, via the same kernel path — 20 seconds after the
first timeout, and **it failed**.

So adding `13d3:3503` to btusb's quirks table would most likely **not** have prevented
this hang. The kernel handler would have fired at roughly the same moment and done
roughly the same thing.

This does not invalidate the finding that the device is missing from the quirks table —
that remains true and is worth fixing. It does invalidate the claimed *benefit*. The bug
report and fix proposal must be corrected before submission: the honest claim is now
"this device gets no cmd_timeout handler", not "adding it would fix the hang".

Open question worth testing: whether a reset issued *earlier* — during the AVDTP/SCO
teardown, before any HCI command times out — would succeed where this one failed. That
would require watching for AVDTP errors rather than `tx timeout`.

## Instrumentation verdict

Everything built for this worked:

- verbose watchdog logged `window: 1/3`, `2/3`, `3/3` then the intervention
- cooldown suppression logged clearly (`threshold reached (14/3) but suppressed by
  cooldown (59s remaining)`) — without it, the 14 subsequent timeouts would have looked
  like the watchdog ignoring them
- the HCI capture covered the exact moment, and is what revealed the SCO detail

## Files

- `kernel.log` — 56 lines, filtered
- `watchdog.log` — full detection and recovery attempt
- `bluetoothd.log`
- `timeline.txt` — merged chronology
- `hci-captures.txt` — 5 btsnoop files; `bt-20260810-072446.btsnoop` is the one that
  matters

⚠️ The btsnoop is **not committed** — it contains device addresses and SCO audio
payload. Review before attaching anywhere.

## Current state

Controller is off the USB bus. **A cold power-off is required.**
