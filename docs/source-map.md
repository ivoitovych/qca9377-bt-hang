# Source map — every component in the path, and whether we can see it

**Why this file exists.** The source reading done so far has covered **two**
components: `drivers/bluetooth/btusb.c` and `net/bluetooth/hci_core.c`. The
operator has asked repeatedly for the *whole* stack to be read, on the
expectation that the fault is multi-layer, and a review assembled one component
at a time produces a fractured picture: each reading is locally sound and
nothing joins them.

This is the register that has to exist first. It is not a review. It says what
the components **are**, what each one can break, what in **our own record**
implicates it, and — the part that changed the plan — **whether we can currently
observe it at all**.

⚠️ **The finding to read before the table.** Our capture scope is three systemd
units and the kernel:

```console
$ grep -ohE '\-u [a-z][a-zA-Z0-9.-]+' tools/bt-incident tools/bt-snapshot bin/bt-evidence tools/bt-context | sort -u
-u bluetooth
-u bt-hang-watchdog
-u bt-trace
```

So of the components below, **two are captured** — the kernel and `bluetoothd`.
One is visible only second-hand. The rest are blind. `EX-002` establishes that
opening the GNOME Bluetooth panel deterministically drives this controller into
a desync at a 16.0 s cadence — and **nothing in this project captures a single
line from GNOME**. A source review of a layer we hold no logs from can produce a
reading that is plausible and unverifiable, which is the failure mode this
record keeps catching in itself.

**Widening the capture scope is therefore a prerequisite for the review, not a
follow-up to it.**

---

## The register

`seen?` — **captured**: our tooling collects its log. **second-hand**: we see it
only as another component describes it. **blind**: no capture reaches it.

`read?` — has its source been read *for this investigation*.

| # | layer | component | source that matters | what it can break | seen? | read? |
|---|---|---|---|---|---|---|
| 1 | desktop UI | `gnome-control-center` | `panels/bluetooth/cc-bluetooth-panel.c` | the on/off switch, how controller state is presented | **blind** | no |
| 2 | desktop UI | `gnome-bluetooth` | `lib/bluetooth-client.c`, `lib/bluetooth-settings-widget.c` | discovery lifecycle, default-adapter power, the D-Bus view of BlueZ | **blind** | no |
| 3 | desktop UI | `gnome-shell` | Bluetooth quick-settings | a second, independent route to power/connect | **blind** | no |
| 4 | killswitch | `gnome-settings-daemon` rfkill plugin | `plugins/rfkill/gsd-rfkill-manager.c`, `rfkill-glib.c` | `/dev/rfkill` writes — the "turn it off and it never comes back" path | **blind** | no |
| 5 | IPC | system D-Bus | `org.bluez.*` | transport only; cannot explain a lost `hci0` | second-hand | n/a |
| 6 | BT daemon | **BlueZ 5.72** (`5.72-0ubuntu5.5`) | `src/adapter.c`, `src/device.c`, `src/agent.c`, `src/shared/mgmt.c` | power, discovery, pairing, adapter state machine — and it **crashes**, `EX-032` | **captured** | no |
| 7 | kernel mgmt | `net/bluetooth/mgmt.c` | — | BlueZ ↔ kernel control, controller index | captured | no |
| 8 | kernel SCO | `net/bluetooth/sco.c`, `hci_conn.c` | voice setting, air mode, SCO MTU | the `corrupted SCO packet` and the three disagreeing MTUs in `EX-031` | captured | no |
| 9 | kernel HCI | `net/bluetooth/hci_core.c`, `hci_sync.c`, `hci_event.c` | command queue, timeout, escalation, open/close | **read** — the two-watchdogs/one-escalation finding | captured | **yes** |
| 10 | transport | `drivers/bluetooth/btusb.c` | isoc alt-setting selection, reset, suspend/resume | **read** — alt-1 fallback, `hdev->reset` absent for this ID | captured | **yes** |
| 11 | vendor | `btqca.c` (+ the quirks table) | firmware download, vendor reset | never runs for `13d3:3503` — that is `EX-001` | captured | partial |
| 12 | firmware | `linux-firmware` QCA ROME blobs | — | the rampatch/NVM that are **never loaded** here | n/a | n/a |
| 13 | USB core | `drivers/usb/core/hub.c`, `driver.c`, PM | re-enumeration, port reset, runtime suspend | the stage-2 collapse and the failed re-enumeration | captured (kernel log) | no |
| 14 | host controller | `xhci_hcd` | the port the controller hangs off | `-110` on descriptor reads after collapse | captured (kernel log) | no |
| 15 | platform | ACPI / UEFI / EC | — | the power rail — why **power-off recovers and reboot does not** | **blind** | no |
| 16 | audio | PipeWire `spa/plugins/bluez5/*` | `bluez5-dbus.c`, `backend-native.c` | A2DP/HFP profile handling — `EX-030`'s transport release | second-hand | no |
| 17 | audio policy | WirePlumber BlueZ monitor | — | which profile is selected, and when it is dropped | second-hand | no |

### How the "seen?" column was established

```console
$ cat evidence/sessions/*/*.log | grep -ohE '^[A-Za-z]{3} [0-9]{2} [0-9:.]+ [a-z]+ ([a-zA-Z0-9_.-]+)\[' \
  | awk '{print $NF}' | tr -d '[' | sort | uniq -c | sort -rn
  13728 bluetoothd
    346 bt-trace
    177 bt-hang-watchdog
     76 systemd
```

`wireplumber` appears in `EX-030` only inside lines **`bluetoothd` wrote about
it** — "wireplumber (owner :1.86) issues Release on the media transport". That is
BlueZ naming its D-Bus caller, not WirePlumber's own log. Hence *second-hand*:
we can see that it acted, never why.

---

## What this means for the all-layers review

1. **Rows 1–4 cannot be reviewed against behaviour today.** Reading
   `gnome-bluetooth` would produce a description of what the code does, with no
   way to check it against what happened on the machine. `EX-002` says this
   layer is a trigger; we have no record of what it sent.
2. **Row 15 is the one that explains the most and is instrumented the least.**
   Power-off recovers, reboot does not (`EX-027`, `EX-028`, `EX-034`). That is a
   statement about a power domain, and no source in rows 1–14 can settle it.
3. **Rows 6, 8 and 13 are captured and unread** — the best value per unit of
   work, because the reading can be checked against logs we already hold.

**Suggested order, on that basis:** row 8 (`sco.c`, and `EX-031`'s three
disagreeing MTUs sit on the isochronous path we believe is forced to alt 1),
then row 6 (BlueZ, where `EX-032`'s three crashes at one offset live), then row
13. Rows 1–4 after the capture scope is widened; row 15 needs the operator and
the hardware.

## What can be excluded, and on what grounds

Exclusions are worth as much as findings, and each of these is evidential
rather than an assumption:

| excluded | why | evidence |
|---|---|---|
| PipeWire / WirePlumber as the **cause** of the controller wedge | the controller stops answering HCI with the audio stack uninvolved; and an audio-server transport release is a *separate* failure mode already separated from it | `EX-030` vs `BT-1` |
| D-Bus transport | a wedged `hci0` is below it, and the daemon keeps answering D-Bus while the controller is dead | `EX-032` — adapter `Powered=true` over D-Bus while discovery is dead |
| vendor firmware download path | it never runs on this device — no rampatch, no NVM, in any boot | `EX-001`, `EX-019` |

⚠️ **Not excluded, and often assumed to be:** the GNOME layer. It is untested,
not innocent. `EX-002` is the strongest evidence in this record that a userspace
component deterministically provokes the controller.

---

## Register discipline

This file is a **register, not a report**. It is expected to change: the `read?`
column moves as the review proceeds, and the `seen?` column moves as capture
widens. Findings go in `reviews/`, dated and append-only; this stays current.

Every row names a component that a real observation in this record touches.
Nothing is here because it is part of a generic Bluetooth stack diagram.
