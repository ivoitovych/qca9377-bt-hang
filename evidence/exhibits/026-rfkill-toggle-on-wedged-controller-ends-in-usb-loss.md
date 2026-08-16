# EX-026 — rfkill-toggle-on-wedged-controller-ends-in-usb-loss

**Claim.** A complete fault-to-USB-loss chain captured end to end in 111 s, with no
tool of ours running: `0x0428` SCO setup → HCI non-response at 4.1 s → an operator
pressing the Bluetooth button 6.1 s later → the rfkill power-off timing out (-110) →
a USB reset **this project did not issue** → `USB disconnect` 85.6 s after that reset.
The controller has not returned to the bus since.

**Relevance.** Three things this record did not previously have. It is the first stage-2
progression observed with the watchdog **disabled and not installed**, so the reset
cannot be ours. It is the first fault reported by a household member rather than
instrumented on purpose, and the account was checkable against the journal line by
line. And it is the shortest SCO-to-timeout interval seen — 4.1 s against a previous
floor of 7.6 s.

## Extraction method

Re-runnable as-is on the affected machine, while boot `60ddb417` is retained:

```console
$ journalctl -k -b 0 --since '2026-08-16 15:37:49' --until '2026-08-16 15:39:41' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|Looking for Alt no|tx timeout|powering off device on rfkill|setting interface failed|name hci0 blocked|reset full-speed|device descriptor read|USB disconnect' | grep -vE 'blocked 0$' | head -20
```

## Output

Verbatim, 18 line(s), exit status 0.

```
2026-08-16T15:37:49.918327+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-16T15:37:49.948290+02:00 n kernel: Looking for Alt no :6
2026-08-16T15:37:49.948300+02:00 n kernel: Looking for Alt no :3
2026-08-16T15:37:54.056193+02:00 n kernel: Bluetooth: hci0: command 0x0c1a tx timeout
2026-08-16T15:37:56.105184+02:00 n kernel: Bluetooth: hci0: command 0x0c1a tx timeout
2026-08-16T15:38:00.148188+02:00 n kernel: 000000009a78155a name hci0 blocked 1
2026-08-16T15:38:02.185213+02:00 n kernel: Bluetooth: hci0: command 0x0c1a tx timeout
2026-08-16T15:38:02.185465+02:00 n kernel: Bluetooth: hci0: Error when powering off device on rfkill (-110)
2026-08-16T15:38:07.307313+02:00 n kernel: Bluetooth: hci0: setting interface failed (110)
2026-08-16T15:38:15.099224+02:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-08-16T15:38:30.456254+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-16T15:38:46.328201+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-16T15:38:46.544224+02:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-08-16T15:39:02.200236+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-16T15:39:18.072225+02:00 n kernel: usb 3-3: device descriptor read/64, error -110
2026-08-16T15:39:18.290207+02:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-08-16T15:39:29.546219+02:00 n kernel: usb 3-3: reset full-speed USB device number 2 using xhci_hcd
2026-08-16T15:39:40.695830+02:00 n kernel: usb 3-3: USB disconnect, device number 2
```

The `blocked 0` lines are filtered out of the extract because the unblock repeated
seventeen times over 6.5 s. The first is at `15:38:09.600201`, and their repetition is
itself part of the story — see "What the operator saw".

## The chain, with intervals

```
15:37:49.918  hci0 opcode 0x0428 plen 17           SCO setup — the known trigger
15:37:49.948  Looking for Alt no :6 / :3           btusb switches USB alt-setting
              ┃ 4.138 s
15:37:54.056  command 0x0c1a tx timeout            HCI non-response begins
              ┃ 6.092 s   ← controller is ALREADY wedged here
15:38:00.148  name hci0 blocked 1                  operator presses the button
15:38:02.185  Error when powering off device on rfkill (-110)
15:38:07.307  setting interface failed (110)
15:38:09.600  name hci0 blocked 0                  operator presses it again
              ┃ 5.499 s
15:38:15.099  usb 3-3: reset full-speed USB device   ← NOT OURS
              ┃ 85.596 s
15:39:40.696  usb 3-3: USB disconnect, device number 2
```

Still absent at the time of writing: `/sys/bus/usb/devices/3-3` does not exist and
`/sys/class/bluetooth/` is empty.

## The button did not cause the fault — it arrived 6.1 s late

The household account was that pressing the Bluetooth button disabled the controller
and pressing it again did not bring it back. The first half is not what happened and
the second half is exactly what happened.

The controller had already stopped answering HCI at `15:37:54.056`, **6.092 s before**
the button was pressed at `15:38:00.148`, and it stopped in the signature this project
has recorded five times: `0x0428` Setup Synchronous Connection, the alternate-setting
switch, then a command that is never answered. The button press then met a controller
that could not answer, which is why the power-off returned `-110` rather than
succeeding.

So the operator's action did not begin the fault. It did, however, land inside it — and
what followed the action is the part that destroyed the device.

## The reset was not ours, and it was not `hdev->reset` either

This is the finding that distinguishes this exhibit from `EX-021` and `EX-023`, where
the reset was ours by construction.

| candidate | ruled in or out | evidence |
|---|---|---|
| `bt-hang-watchdog` | **out** | `systemctl is-active` → `inactive`; `is-enabled` → `disabled`; `journalctl -u` → `No entries` |
| our tooling generally | **out** | 12 tools drifted and the watchdog **not installed**; no `bt-*` process ran this boot |
| `btusb_qca_reset` (`hdev->reset`) | **out** | its log string `Resetting usb device` occurs **0** times this boot |
| driver unbind / reload | **out** | `deregistering interface driver btusb` occurs **0** times this boot |
| `hci_cmd_timeout()` → `hdev->reset()` | **out** | `13d3:3503` is absent from btusb's table, so no `reset` is installed — re-verified against this kernel's binary |

What remains is that `usb 3-3: reset full-speed USB device number 2 using xhci_hcd` is
printed by usbcore's `usb_reset_and_verify_device()`. **Something in the kernel's own
USB path reset the device 5.5 s after the rfkill unblock, and this project did not ask
it to.** The precise caller is **not established** and is not guessed at here.

⚠️ One hypothesis is recorded because it is testable, not because it is supported:
`power/control` was `auto` on this device and the udev rule that pins it to `on` is
**not installed on this machine** (`/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules`
does not exist). A runtime-suspend whose resume fails is one usbcore path to
`usb_reset_device()`. No suspend or resume line appears in the journal for `usb 3-3`,
so this is unconfirmed in both directions — usbcore's dynamic debug was not enabled.

## Reset → disconnect, now n = 3

| | window age at reset | reset → USB disconnect | reset issued by |
|---|---:|---:|---|
| `EX-023` | 12107 s | 11.2 s | us, deliberately |
| 2026-08-15 | 613 s | 85.6 s | us, deliberately |
| **this one** | **21.0 s** | **85.6 s** | **the kernel, unasked** |

**The outcome remains invariant and the duration remains not.** Three resets at window
ages spanning 21 s to 12107 s, all fatal. The interval is 11.2–85.6 s, and any single
figure would misrepresent it — the error that produced the retired "45–66 s".

The two 85.6 s values agreeing to the tenth of a second is noted and **not interpreted**.
It is consistent with the interval being set by usbcore's fixed descriptor-read retry
schedule rather than by anything about the controller, which would make it an artefact
of the host and not a property of the device. One coincidence is not evidence for that.

## What the operator saw

Seventeen `blocked 0` events in 6.5 s, and `gsd-rfkill` logging
`Failed to set RFKill: Stream has outstanding operation` — the Settings panel and the
button both trying to re-enable an adapter that could not answer. From the kitchen this
looks like "I pressed it again and nothing happened". From the journal it is the
desktop stack retrying against a dead controller until usbcore took the device off the
bus.

## Reading

**What this adds.** A stage-2 progression whose reset was not ours is the observation
this record has been missing, because the standing objection to `EX-021` and `EX-023`
is that we caused the ending. Here nothing of ours was running.

**What it does not add.** It is *not* a spontaneous stage 2. An operator toggled rfkill
inside the fault window, and every element after `15:38:00.148` is downstream of that.
The claim that has held across every observation still holds unchanged: **a USB
collapse has never begun before something touched the controller.** This is a new
*kind* of toucher — the kernel's own USB path, reacting to a user-space rfkill
sequence — not an absence of one.

**What it costs the upstream argument.** Nothing, and it sharpens one point. The
proposed patch would install `hdev->reset` and have `hci_cmd_timeout()` call it on the
first timeout. This exhibit shows a reset arriving 21 s into a fault window and killing
the device. It is the third such demonstration and the first not authored by us.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-16T15:47:00+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `60ddb417` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260816-154450-rfkill-toggle-then-usb-loss-20260816` |
