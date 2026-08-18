# EX-032 — bluetoothd-segfault-discovery-never-restarts

**Claim.** `bluetoothd` 5.72 segfaulted twice on this boot at the **same code offset**
(`367e5`) reading the **same address** (`0x10`), and after the second crash device discovery
never started again. Opening the Bluetooth panel six hours later leaves `Powered = true`
and `Discovering = false` with nothing in the journal — while the controller is healthy:
**zero** command timeouts against 7999 opcode lines.

**Relevance.** This is a **third distinct failure mode**, and the first that is not the
controller at all. `BT-1` wedges the controller and leaves HCI timeouts in the kernel log;
`EX-030` is an audio-server transport release; this is a userspace crash in BlueZ that
leaves the adapter powered and permanently non-scanning. An operator sees the same thing in
all three — Bluetooth "not working" — and the record previously offered no way to tell this
one apart.

⚠️ The symptom reported was "the wheel is dead", meaning the panel's *scanning* spinner is
not rotating. That is the literal state: the adapter is not discovering.

## Extraction method

Re-runnable as-is on the affected machine, while boot `e9399c8c` is retained:

```console
$ journalctl -b 0 --no-pager -o short-iso | grep -E 'segfault|Failed with result .core-dump.' | tail -4; busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered; busctl get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Discovering; journalctl -k -b 0 --no-pager | grep -cE 'tx timeout'; journalctl -b 0 --no-pager -o short-iso | grep -E 'start_discovery_complete|trigger_start_discovery' | tail -1
```

## Output

Verbatim, 8 line(s), exit status 0.

```
2026-08-18T18:46:06+02:00 n kernel: bluetoothd[2862]: segfault at 10 ip 00005c48db1977e5 sp 00007fff41437110 error 4 in bluetoothd[367e5,5c48db186000+f3000] likely on CPU 9 (core 4, socket 0)
2026-08-18T18:46:07+02:00 n systemd[1]: bluetooth.service: Failed with result 'core-dump'.
2026-08-18T22:15:00+02:00 n kernel: bluetoothd[313564]: segfault at 10 ip 000060ff12be87e5 sp 00007fff35b2f190 error 4 in bluetoothd[367e5,60ff12bd7000+f3000] likely on CPU 6 (core 3, socket 0)
2026-08-18T22:15:00+02:00 n systemd[1]: bluetooth.service: Failed with result 'core-dump'.
b true
b false
0
2026-08-18T18:46:04+02:00 n bluetoothd[2862]: src/adapter.c:start_discovery_complete() status 0x00
```

The last line is the point: the most recent successful discovery on this boot completed at
**18:46:04**, two seconds before the first crash. Nothing has started a discovery since —
including the panel session at 00:52 that prompted this capture.

## The crash is deterministic, not corruption

| | crash 1 | crash 2 |
|---|---|---|
| time | `2026-08-18T18:46:06` | `2026-08-18T22:15:00` |
| pid | 2862 | 313564 |
| fault address | `10` | `10` |
| **offset into `bluetoothd`** | **`367e5`** | **`367e5`** |
| access | `error 4` — user-mode read of an unmapped page | same |
| CPU | 9 | 6 |

Two processes, four hours apart, on different CPUs, faulting at the same offset reading the
same address. That is one code path dereferencing a null pointer at a fixed field offset —
a reproducible defect in `bluez 5.72-0ubuntu5.5`, not memory corruption and not a hardware
symptom.

The second crash is immediately preceded by:

```
2026-08-18T22:15:00 bluetoothd[313564]: profiles/audio/a2dp.c:a2dp_config() avdtp_close failed
```

and the restarted process reports:

```
2026-08-18T22:15:00 bluetoothd[348170]: profiles/sap/server.c:sap_server_register() Sap driver initialization failed.
2026-08-18T22:15:00 bluetoothd[348170]: Failed to set privacy: Rejected (0x0b)
```

## The controller was not involved

| check | this boot |
|---|---:|
| `opcode 0x` lines (positive control) | 7999 |
| `command 0x…​ tx timeout` | **0** |
| `usb 3-3` / `USB disconnect` lines | 8 — enumeration only |
| `/sys/bus/usb/devices/3-3` | present |
| `/sys/class/bluetooth/hci0` | present |
| uptime at capture | 1 d 13 h |

The adapter answered HCI throughout, including `0x040A Reject Connection Request` three
times at 00:52:12–14 while the panel was open. Nothing here resembles `BT-1`.

## Telling the three failure modes apart

Recorded so an operator report can be classified from the journal rather than from the
description, extending the test stated in `EX-030`:

| | kernel `tx timeout` | `0x0428` then `Looking for Alt no` | `bluetoothd` segfault | adapter `Powered` |
|---|---|---|---|---|
| `BT-1` controller wedge | **yes** | yes | no | true, unresponsive |
| `EX-030` transport release | no | no | no | true, recovers in ~0.6 s |
| **this** | no | no | **yes** | true, `Discovering = false` forever |

## Reading

**What this establishes.** Bluetooth can be unusable on this machine for a reason that has
nothing to do with the QCA9377. A BlueZ crash leaves the adapter powered and the daemon
running — `ActiveState=active`, `NRestarts=2` — so every surface check says healthy while
discovery is silently dead until the service is restarted or the machine rebooted.

**Why it matters to the upstream report.** It is a confounder. Any operator account of
"Bluetooth stopped working" that is not backed by a kernel timeout may be this instead, and
the record should not pool the two. It also means the failure *rate* this project has
quoted from operator experience covers at least three mechanisms.

**What it does not establish.** The crash's cause is not identified here — the offset is
recorded but not symbolised, `coredumpctl` is not installed on this host, and no core file
was retained. The link to `a2dp_config() avdtp_close failed` is temporal, not proven.
Whether the *first* crash also killed discovery cannot be tested, because discovery
succeeded two seconds earlier and was never attempted again in that process's life.

**Not attributed to the controller, and deliberately not attributed to this project's
tooling either.** `bt-hang-watchdog` is not installed and was not running; nothing of ours
issues MGMT commands.

**What would settle it.** Install `systemd-coredump`, keep the next core, and symbolise
offset `367e5` against the `bluez` debug symbols — that names the function in one step. A
restart of `bluetooth.service` should also be recorded before and after, to confirm the
adapter resumes discovery, which would make this recoverable without a reboot.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-19T00:57:06+02:00` |
| kernel | `7.0.0-28-generic` |
| bluez | `5.72-0ubuntu5.5` |
| boot id | `e9399c8c` |
| device | `13d3:3503` QCA9377 (ROME) — healthy throughout |
| exit status | `0` |
| redacted | `no` |
| session | `evidence/sessions/20260819-005706-bluetoothd-segfault-discovery-never-starts` |
