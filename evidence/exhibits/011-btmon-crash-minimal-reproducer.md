# EX-011 — btmon-crash-minimal-reproducer

**Claim.** btmon 5.72 aborts deterministically when it observes an HCI command/response exchange performed by a client on a **raw HCI socket**. `hciconfig hci0 name` produces exactly one abort, 1:1, provided btmon has finished restarting from the previous one.

**⚠️ Corrected before publication.** This exhibit first claimed the trigger was specific to Read Local Name (0x03|0x0014) and its 252-byte Command Complete, inferred from the events btmon lost immediately before each restart. Testing the alternatives refuted that within minutes:

| Probe | Sends an HCI command? | Socket | Aborts btmon |
|---|---|---|---|
| `hciconfig hci0 name` | yes (Read Local Name) | raw HCI | **3 of 3** |
| `hciconfig hci0 version` | yes (Read Local Version) | raw HCI | **3 of 3** |
| `hciconfig hci0` | no — `HCIGETDEVINFO` ioctl only | raw HCI | 0 of 3 |
| `bluetoothctl show` | yes, via MGMT | D-Bus/MGMT | 0 of 3 |

So it is neither the specific command nor merely opening a raw socket: the bare `hciconfig` opens one and survives, and a command sent over MGMT survives. What both crashing cases share is a **command/response exchange on a raw HCI socket**, observed by the monitor. The counts below are from the original run, in which the trigger was `hciconfig hci0 name`.

**Relevance.** A minimal reproducer for BT-4, reducing it from '67-74 aborts per boot for unknown reasons' to a single command. It also explains the crash rate: this project's own probes call 'hciconfig <dev> name' as a liveness check — bt-state on every invocation and bt-health-snapshot on a timer — so the monitoring has been continuously crashing the capture it depends on. Found by comparing the two independent capture paths (bt-capdiff): the decode-free capture retained the Read Local Name exchange that btmon lost one second before each of its restarts.

## Extraction method

Re-runnable as-is on the affected machine:

```console
$ echo -n 'btmon aborts before: '; journalctl -u bt-trace -b 0 --no-pager -o cat | grep -c exited; hciconfig hci0 name >/dev/null 2>&1; sleep 4; hciconfig hci0 name >/dev/null 2>&1; sleep 4; hciconfig hci0 name >/dev/null 2>&1; sleep 4; echo -n 'btmon aborts after 3 spaced calls: '; journalctl -u bt-trace -b 0 --no-pager -o cat | grep -c exited
```

## Output

Verbatim, 2 line(s), exit status 0.

```
btmon aborts before: 79
btmon aborts after 3 spaced calls: 82
```

**Evidence window.** not placeable — the output is two counts and neither is a time.

> **Annotation added 2026-08-22 (`BL-09`), derived from this exhibit's own
> content. The captured output above is untouched.** `journalctl -u bt-trace -b 0 … | grep -c`
> returns a number. The evidence is the capture boot itself, whose id the provenance
> records, and a boot id is not an instant. Re-running the extraction against the
> abort lines with `-o short-iso-precise` would place it.

## Provenance

| field | value |
|---|---|
| captured | `2026-08-12T19:22:06+02:00` |
| kernel | `7.0.0-28-generic` |
| boot id | `d28ebac2` |
| device | `13d3:3503` QCA9377 (ROME) |
| exit status | `0` |
| redacted | `no` |
