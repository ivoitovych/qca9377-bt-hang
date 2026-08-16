# EX-024 — two-headsets-one-signature

**Claim.** The fault reproduces on two different vendors' headsets with an identical signature: 0x0428 Setup Synchronous Connection, the USB alternate-setting switch, then an unanswered 0x0406 teardown. Device strings taken from the journal, not from recollection: MOMENTUM 4 and 联想thinkplus-GM2 pro.

**Relevance.** Every instrumented failure before 2026-08-15 was the Sennheiser. A reviewer's first objection to a single-peripheral record is peripheral specificity — that the headset's codec or HFP implementation is at fault rather than the controller. Two vendors, two chipsets, one signature answers that with data instead of argument, and relocates the claim to the QCA9377's synchronous-link path.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ journalctl -b -4 --since '2026-08-14 20:25' --until '2026-08-14 20:35' --no-pager | grep -oE 'MOMENTUM 4' | head -1; journalctl -b 0 --since '2026-08-15 20:50' --until '2026-08-15 21:05' --no-pager | grep -oE 'thinkplus-GM2 pro' | head -1; echo '--- signature, 2026-08-15 ---'; journalctl -k -b 0 --since '2026-08-15 21:02:10' --until '2026-08-15 21:02:40' --no-pager -o short-iso-precise | grep -E 'opcode 0x0428|Alt no|tx timeout|setting interface'
```

## Output

Verbatim, 8 line(s), exit status 0.

```
MOMENTUM 4
thinkplus-GM2 pro
--- signature, 2026-08-15 ---
2026-08-15T21:02:15.017017+02:00 n kernel: hci0 opcode 0x0428 plen 17
2026-08-15T21:02:15.050001+02:00 n kernel: Looking for Alt no :6
2026-08-15T21:02:15.050039+02:00 n kernel: Looking for Alt no :3
2026-08-15T21:02:31.230870+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-15T21:02:36.671887+02:00 n kernel: Bluetooth: hci0: setting interface failed (110)
```

## A note on the second device's name

The extraction above greps `thinkplus-GM2 pro`, so the output shows the ASCII
portion only. The full string the stack recorded carries a non-ASCII vendor
prefix:

```
bluetoothd: profiles/audio/avctp.c:init_uinput() AVRCP: uinput initialized for 联想thinkplus-GM2 pro
kernel: input: 联想thinkplus-GM2 pro (AVRCP) as /devices/virtual/input/input28
systemd-logind: Watching system buttons on /dev/input/event18 (联想thinkplus-GM2 pro (AVRCP))
```

联想 is Lenovo. Three independent components — bluetoothd, the kernel input
layer and logind — recorded the same string, so it is the device's advertised
name and not one component's transcription.

The grep pattern is left as it is rather than widened, because a pattern
containing non-ASCII is a portability hazard in a command a maintainer is
invited to re-run, and the ASCII substring identifies the model unambiguously.

## The signature, across both devices

| | 2026-08-14 | 2026-08-15 |
|---|---|---|
| device | `MOMENTUM 4` | `联想thinkplus-GM2 pro` |
| vendor | Sennheiser | Lenovo |
| `0x0428` Setup Synchronous Connection | ✔ | ✔ |
| `Looking for Alt no` (USB alt-setting switch) | ✔ | ✔ |
| unanswered `0x0406` teardown | ✔ | ✔ |
| `setting interface failed (110)` | ✔ | ✔ |
| SCO setup → first timeout | 7.6 s | 16.2 s |

## Reading

**The interval is a distribution, not a constant.** Across four instrumented
instances it spans **7.6–16.2 s**. Quoting a single figure is precisely the
error that produced the retired "45–66 s" claim, which turned out to be the
watchdog's reaction time rather than the fault's timing.

**What two vendors buys.** A single-peripheral record supports "this headset and
this adapter disagree". Two vendors, with different Bluetooth chipsets and
independently written HFP/codec implementations, producing an identical
kernel-side sequence relocates the fault to the shared component — the
QCA9377's synchronous-link path and the `btusb` alternate-setting switch that
serves it. That is the claim `BT-1` has always made, now supported rather than
asserted.

**What it does not establish.** Two devices is not a survey. It excludes
per-peripheral idiosyncrasy as the *sole* explanation; it does not show the
fault is independent of the negotiated link parameters, which both devices may
happen to share. `bt-sco --window` exists to compare the whole event window
rather than the parameter fields, and that comparison has not been made across
these two.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-16T02:48:44+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `95d14e7a` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
