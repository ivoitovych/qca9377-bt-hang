# EX-039 — hci-reset-fails-so-the-toggle-cannot-recover

**Claim.** Toggling Bluetooth off and on after a wedge cannot work, and the log says why:
the re-enable path issues **`HCI_Reset` (opcode `0x0c03`) and it times out at `-110`**. The
adapter is never unregistered, so `hci0` remains — but it can never initialise, which is
what the operator sees as Bluetooth having *disappeared*.

**Relevance.** This closes the recovery question with a positive observation rather than an
absence. The record already had two structural arguments — `hci_cmd_timeout()` calls
`hdev->reset()`, which is NULL for `13d3:3503` because it matches no quirks entry, and Linux
has no periodic USB device recovery — and one empirical one: a 9 h 45 m untreated window with
no self-recovery (`EX-033`). ⚠️ **Those are all statements about what does *not* happen.**
This is the thing that *does*: the one software reset path that is explicitly commanded, by
the operator, through the GUI, fails at the USB layer.

## Operator account, which is what prompted this

> "the rolling wheel is actually missing. And this means that if I would try to disable
> Bluetooth and try to re-enable it, the Bluetooth will disappear until the power off and
> power on."

Both halves check out against the logs, the second with a refinement — see below.

## Extraction method

Re-runnable as-is while boot `c8342e9b` is retained (index `-25` at the time of writing;
**use the boot id**, indices shift on every reboot):

```console
$ journalctl -b -25 --since '2026-08-25 17:09:43' --until '2026-08-25 17:09:48' --no-pager -o short-iso-precise | grep -E 'name hci0 blocked|0x0406 tx timeout|adapter_set_power_state|Opcode 0x0c03 failed|end: err'
```

## Output

Verbatim, 11 line(s), exit status 0.

```
2026-08-25T17:09:43.217850+02:00 n kernel: 00000000ed3530ce name hci0 blocked 1
2026-08-25T17:09:45.230847+02:00 n kernel: hci0: end: err -110
2026-08-25T17:09:45.231019+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout
2026-08-25T17:09:45.254610+02:00 n bluetoothd[196730]: src/adapter.c:adapter_set_power_state() off-blocked
2026-08-25T17:09:45.646054+02:00 n bluetoothd[196730]: src/adapter.c:adapter_set_power_state() off
2026-08-25T17:09:45.646070+02:00 n bluetoothd[196730]: src/adapter.c:adapter_set_power_state() off-enabling
2026-08-25T17:09:45.646831+02:00 n kernel: 00000000ed3530ce name hci0 blocked 0
2026-08-25T17:09:46.411841+02:00 n kernel: 00000000ed3530ce name hci0 blocked 0
2026-08-25T17:09:47.661969+02:00 n kernel: hci0: end: err -110
2026-08-25T17:09:47.662054+02:00 n kernel: Bluetooth: hci0: Opcode 0x0c03 failed: -110
2026-08-25T17:09:47.662238+02:00 n bluetoothd[196730]: src/adapter.c:adapter_set_power_state() on
```

## Reading

```
17:09:43.217  rfkill blocked 1          operator switches Bluetooth OFF
17:09:45.231  0x0406 tx timeout         the teardown Disconnect is not answered either
17:09:45.254  power state off-blocked
17:09:45.646  power state off → off-enabling
17:09:45.646  rfkill blocked 0          operator switches Bluetooth ON
              ┃
17:09:47.662  Opcode 0x0c03 failed: -110    ← HCI_Reset TIMES OUT
17:09:47.662  power state on                ← BlueZ's INTENT, not a success
```

**`0x0c03` is `HCI_Reset`.** It is the first command of the initialisation sequence, and the
controller does not answer it. `-110` is `ETIMEDOUT`.

⚠️ **`adapter_set_power_state() on` is the trap in this sequence.** It is printed 269 µs
*after* the reset failed, and it means only that BlueZ set its own state variable. Anything
reading that line as "the adapter recovered" is reading BlueZ's intention as the
controller's condition. The same confusion is why `bt-snapshot`'s BlueZ health block is
labelled *last logged state, NOT read from the adapter*.

## The operator's model, refined

| claim | verdict |
|---|---|
| the spinner is missing | ✔ and it maps exactly — see the table below |
| toggling will not bring it back | ✔ `HCI_Reset` fails at `-110` |
| only power off and on recovers it | ✔ consistent with `EX-033`'s 9 h 45 m and with no recorded software recovery |
| "Bluetooth will disappear" | **refined**: `hci0` is never unregistered and stays in the kernel. There is no `USB disconnect`, no unbind. What disappears is a *working* adapter — the device is present and permanently unable to initialise. |

The distinction matters for the bug report: this is **not** a device that falls off the bus
(that is the separate stage-2 shape). It is an enumerated device that fails every command,
including its own reset.

## Recognising it from the GUI, with no tools

⚠️ **Two different faults produce the identical appearance**, and the operator cannot tell
them apart by eye. Both show Bluetooth on with no spinner.

| | `BT-1` — controller wedge (this) | `EX-032` — BlueZ crash |
|---|---|---|
| `powered` | `yes` | `yes` |
| `discovering` | `no` | `no` |
| last discovery OK | **before** the first timeout | **before** the crash |
| command timeouts | **many** | **0** |
| `bluetoothd` crashes | 0 | **≥1** |
| controller answers | **no** | yes |
| recovery | **full power-off** | restart `bluetooth.service` |

The live state at the time of writing, which is the `BT-1` column:

```
powered            yes          2026-09-13T01:00:18.496683+02:00
discovering        no           2026-09-13T00:34:32.053322+02:00
last discovery OK  2026-09-13T00:34:31.333259+02:00     ← 20 min BEFORE the 00:54:57 fault
command timeouts   26
```

**The spinner is `discovering`.** It is absent because no discovery has completed since the
fault, and none can. `bt-snapshot`'s health block is the tool-side reading of exactly the
thing the operator was looking at.

## What this does not establish

**It does not prove no software recovery exists** — only that the one the GUI offers does
not. An unbind/rebind of `btusb`, or `USBDEVFS_RESET`, are different paths. ⚠️ The latter has
**three controlled demonstrations of destroying this controller** (`BL` notes, watchdog
history) and must not be tried casually.

**And the 2026-08-25 window was censored by exactly this.** `EX-036` records five operator
rfkill interventions; these lines are two of them. The toggle that produced this evidence is
the same toggle that cost that window its duration measurement. Both facts are true, and
this exhibit exists partly so the next wedge does not need to be toggled to learn anything.

## Provenance

| field | value |
|---|---|
| captured | `2026-09-13T05:10:00+02:00` (from retained boot `c8342e9b`) |
| event date | `2026-08-25T17:09:43+02:00` |
| kernel | `7.0.0-30-generic` |
| bluez | `5.72-0ubuntu5.5` + 31 Ubuntu patches + `patches/bluez/0001`, `0002` |
| device | `13d3:3503` QCA9377 (ROME) |
| boot id | `c8342e9b` |
| exit status | `0` |
| redacted | `no` |
| relates to | `EX-032` (same GUI appearance, different fault), `EX-033`, `EX-036`, `EX-038` |
