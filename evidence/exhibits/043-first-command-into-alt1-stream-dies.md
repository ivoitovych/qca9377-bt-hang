# EX-043 — first-command-into-alt1-stream-dies

**Claim.** Seventh instance, and the first under the **original configuration**
(`autosusp=Y, power=auto`, read live). The transparent SCO link came up on alt 1 and
**streamed 910 27-byte frames for 9.65 s with no HCI command in flight**; the first command
then issued — `0x0406 Disconnect` — was never answered and timed out 2.05 s later.
Setup → fault: **11.874 s**, against 2.08–2.19 s in the six prior instances.

**Relevance.** This reconciles the whole series. The six tight intervals were not a
2.15 s constant; they were **(time to the first command after link-up) + `HCI_CMD_TIMEOUT`**,
and in all six the first command came 34–279 ms after link-up. Here it came at 9.65 s.
**What is invariant is not the interval — it is that the first HCI command issued into a
running alt-1 stream is never answered.** That also accounts for the 4.1–155.8 s "spread"
measured early in the project from other anchors.

And the modified configuration is eliminated as a factor: the fault reproduces under stock
Ubuntu power management, with the endpoint counters, which was the one capture owed.

## Extraction method

Re-runnable while boot `eddd1961` is retained:

```console
$ tools/bt-fault-window --before 40
$ journalctl -k -b 0 --since '2026-09-17 16:51:17.1' --until '2026-09-17 16:51:26.7' --no-pager | grep -cE 'opcode 0x[0-9a-f]+ plen'
$ tools/bt-usbstate | grep 'ALTERNATE SETTING'
$ cat /sys/module/btusb/parameters/enable_autosuspend /sys/bus/usb/devices/3-3/power/control
```

## Output

```
    2026-09-17T16:51:16.907835+02:00 n kernel: hci0 opcode 0x0428 plen 17
    2026-09-17T16:51:17.081678+02:00 n kernel: hci0: hcon 00000000877cb3ab handle 0x0008
    2026-09-17T16:51:17.081780+02:00 n kernel: hci0 evt 5
    2026-09-17T16:51:17.081824+02:00 n kernel: Looking for Alt no :6
    2026-09-17T16:51:17.081861+02:00 n kernel: Looking for Alt no :3
    2026-09-17T16:51:26.731683+02:00 n kernel: hci0: handle 0x08 reason 0x13
    2026-09-17T16:51:26.731743+02:00 n kernel: hci0: opcode 0x0406 plen 3
    2026-09-17T16:51:28.781675+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
  alt-1 (mtu 9) 910, of which 27-byte mSBC: 910 · wider (mtu >9) 0
  0x0428 setup → fault: 11.874 s
0                                        ← commands issued during the 9.65 s stream
  ⚠️  SCO interface is on ALTERNATE SETTING 1, isochronous endpoint 9 bytes
Y
auto
```

## The series, re-read

| | first cmd after link-up | setup → fault | = first-cmd + 2.0 s? |
|---|---|---|---|
| `EX-033` | 36 ms | 2.076 s | ✔ |
| `EX-036` | 279 ms | 2.152 s | ✔ (`0x0406`, named) |
| `EX-037` | 39 ms | 2.151 s | ✔ |
| `EX-038` | 35 ms | 2.191 s | ✔ |
| `EX-040` | 34 ms | 2.140 s | ✔ |
| `EX-042` | ~90 ms | 2.147 s | ✔ |
| **this** | **9,650 ms** | **11.874 s** | **✔** (`0x0406`, named) |

Both instances where the log *names* the dying command name `0x0406 Disconnect, reason
0x13`. The bare-timeout instances are the ones where the first command was an
`hci_cmd_sync`-untracked one issued within ~40 ms — consistent, not contradictory.

## What this does not establish

The **mechanism** is still open: whether the controller's command path is blocked by the
isochronous traffic itself, by the 27-into-9 mismatch, or by something the first command
triggers. It does establish the *shape* a driver test must have: put the link on alt 1,
stream, then issue any command and watch it die.

## Terminator

```
first timeout   2026-09-17T16:51:28.781675+02:00
checked         2026-09-17T23:44:19+02:00     6 h 53 m, 0 interventions, USB layer silent
```

## Provenance

| field | value |
|---|---|
| kernel | `7.0.0-31-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` (guards 0) |
| boot id | `eddd1961` (started 2026-09-17 00:53:06) |
| treatment (live) | **`autosusp=Y, power=auto`, wd=off, probes=off — original configuration** |
| trial | falls in trial-13, which `bt-trial` will close as `CHANGED:` (mode switched mid-trial at 13:40) |
| session | `evidence/sessions/20260917-234432-alt1-wedge-first-under-original-config` |
| confirms | `EX-033`, `EX-036`, `EX-037`, `EX-038`, `EX-040`, `EX-042` |
| refines | the "2.15 s interval" reading in all of them |
