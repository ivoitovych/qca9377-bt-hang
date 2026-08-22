# External review brief — the whole Bluetooth stack, against real observations

**Hand this to a reviewer as-is.** It is self-contained: it assumes no access to
our repository, and it is written so that several independent reviews can be
**merged** rather than merely collected.

---

## 0. What is being asked

A Linux Bluetooth controller becomes unusable during ordinary desktop use and
**only a full power-off restores it — a reboot does not**. This has been observed
across years and across machines from different manufacturers.

We have read the source of **two** components (`drivers/bluetooth/btusb.c`,
`net/bluetooth/hci_core.c`). We are asking for the **rest of the stack** to be
read, in the context of the specific observations in §4.

**We are deliberately not narrowing this.** The working assumption is that one
component can produce error-bearing state or data, a second transforms it, and a
third becomes unusable — so a review restricted to the "obvious" layer returns a
fractured picture. Noise and dead ends are expected and are an acceptable cost.
**A dead end reported as a dead end is a result we want.**

---

## 1. Ground rules — please read, they are not boilerplate

Each of these exists because it has already cost this investigation something.

1. **Cite the version you read.** Kernel Bluetooth changes quickly. A behaviour
   introduced in v5.12 is central to this case; a reading of `master` and a
   reading of the shipped kernel can disagree completely.
2. **Same symptom is not same cause.** `command tx timeout` is an endpoint
   symptom — roughly "disk I/O timeout". Two vendors converging on it does not
   make it one bug. We have already had to retract a claim of this shape.
3. **If you cite a URL, open it.** A previous adviser summarised a forum thread
   as showing a specific reset sequence. All sixteen posts were then read: no
   such sequence, and a different vendor's controller entirely. Anything you
   have not opened, mark as unopened.
4. **Absence of a log line is not absence of the event.** Concretely: in this
   driver, one particular alternate-setting outcome is reached by a bare `else`
   and **logs nothing at all**. We misread our own captures for days because the
   outcome that mattered was the silent one. Before concluding "X did not
   happen", check whether X *would have printed anything*.
5. **Do not assume a recovery callback exists** because the driver defines one.
   Check whether it is installed *for the specific USB ID* — that is a table
   lookup, and the answer here is not the general one.
6. **Negative results are required, not optional.** "I read `sco.c` at v6.8 and
   nothing in it explains OB-04" is a deliverable line, and §7 has a place for it.
7. **Say what would falsify each finding.** A claim with no falsifier is not
   usable in a kernel bug report.

---

## 2. The system

| | |
|---|---|
| Controller | Qualcomm Atheros QCA9377 (ROME), USB ID **`13d3:3503`**, internal |
| Distribution | Ubuntu 24.04 LTS, GNOME desktop |
| Kernel | `7.0.0-28-generic` / `7.0.0-29-generic` |
| BlueZ | **5.72** (`5.72-0ubuntu5.5`) |
| Audio | PipeWire + WirePlumber |
| Peers | Sennheiser MOMENTUM 4, a Lenovo headset, a Tronsmart speaker — **the fault reproduces on more than one peer and more than one vendor** |

Not unique to this machine or this controller: the operator has seen the same
behaviour on a previous laptop from a different manufacturer and a different era.

---

## 3. The operator's three reproducers

These are the scenarios the review should be read against. They may be three
faces of one fault or three different faults — **that question is open and is one
of the things we want answered.**

**S1 — the toggle that does not come back.**
Bluetooth is switched off (often accidentally). Switching it back on fails; the
desktop reports that there is no Bluetooth controller. Nothing short of a
reboot or power cycle restores it.

**S2 — pairing a new device.**
While pairing a headset — which involves touching many parts of the desktop
Bluetooth UI — the stack fails. A power-off/power-on is required afterwards.

**S3 — the spinner that is not spinning.**
A headset is connected and the Bluetooth settings panel is opened. The device
list has a rotating spinner at its top right. **If the spinner is not rotating,
the machine is already in the failure mode.** Toggling Bluetooth off and on at
that moment loses the controller entirely, and only a power cycle recovers it.

⚠️ **The spinner is being treated as a diagnostic indicator, not decoration** —
it is the earliest human-visible sign of the failed state that we know of.

---

## 4. Observations — raw, and deliberately without our interpretation

Each has an ID. **Reference these IDs in your findings.** Log lines are verbatim
from instrumented captures on the affected machine, with dynamic debug enabled.

**OB-01 — a synchronous-connection setup, answered, followed by an anonymous timeout**

```
01:31:10.402706  hci0 opcode 0x0428 plen 17
01:31:10.475497  hcon … handle 0x0004
01:31:10.475608  hci0 evt 5
01:31:10.475637  Looking for Alt no :6
01:31:10.475661  Looking for Alt no :3
01:31:12.551489  Bluetooth: hci0: command tx timeout
```

Note the final line has **no opcode**. An untreated window of 9 h 45 m followed,
with zero USB-layer lines and no intervention of any kind.

*(We have not glossed `evt 5` here on purpose. If you can say what it is and
where it comes from, please do — it is one of the things we would like checked
independently.)*

**OB-02 — three numbers for one packet size**

```
18:24:32.230379  len 90 mtu 9
18:24:32.240341  Bluetooth: hci0: corrupted SCO packet
18:24:32.258340  len 27 mtu 9
18:24:37.489356  Bluetooth: hci0: corrupted SCO packet
```

`hciconfig` reports the controller's `SCO MTU` as `50:8` at the same time.

**OB-03 — HCI Reset times out 2.0 s after the radio is unblocked**

```
11:20:45.732507  … name hci0 blocked 0
11:20:47.718628  hci0: end: err -110
11:20:47.718775  Bluetooth: hci0: Opcode 0x0c03 failed: -110
11:20:47.718854  hci0 urb … status -2 count 0
```

This is **S1** captured under instrumentation.

**OB-04 — the daemon crashes at a fixed code offset**

```
segfault at 10 ip … error 4 in bluetoothd[367e5,…+f3000]
segfault at 10 ip … error 4 in bluetoothd[367e5,…+f3000]
```

Two processes, four hours apart, different CPUs, **same offset `+0x367e5`, same
faulting address `0x10`**. Call site `+0x8304a`, reached via glib dispatch. After
the second crash, device discovery never started again: the adapter reported
`Powered = true` and `Discovering = false` indefinitely, with **zero** HCI
command timeouts — the controller was healthy. Two of the three recorded crashes
follow a discovery operation within 2 s.

**OB-05 — the settings panel is a deterministic trigger**

Opening the GNOME Bluetooth panel drives the controller into an HCI
command-pipeline desync within 0.06–10 s, which then repeats at an **exact 16.0 s
cadence** for as long as the panel stays open — observed to 2480 repeats. The
repeating opcode is `0x2005` (`HCI_LE_Set_Random_Address`).

**OB-06 — reboot does not recover it; power-off does**

Multiple `reboot.target` transitions have failed to recover the controller from
the wedged state. Power-off followed by power-on has recovered it. In one case a
warm reboot from the collapsed state prevented the machine from booting at all
until a 10-second power-button hold.

**OB-07 — a deliberate USB reset makes it worse**

After 3 h 21 m of HCI non-response with zero USB-layer activity and no
intervention, a **single deliberate `USBDEVFS_RESET` produced USB disconnect in
11.15 s**. The device then had to be recovered by power cycling. Reset is not a
neutral probe on this hardware.

**OB-08 — the same hardware is reported not to fail under Windows**

Operator observation under repeated connect/disconnect/mode-change cycles. Not
instrumented; recorded here as an operator report, not as a controlled result.

---

## 5. Components — assignable units

Take one, several, or all. **Please state which IDs you covered**, including any
you opened and found irrelevant.

| ID | component | source that matters |
|---|---|---|
| SM-01 | `gnome-control-center` | `panels/bluetooth/cc-bluetooth-panel.c` |
| SM-02 | `gnome-bluetooth` | `lib/bluetooth-client.c`, `lib/bluetooth-settings-widget.c` |
| SM-03 | `gnome-shell` | Bluetooth quick settings |
| SM-04 | `gnome-settings-daemon` rfkill plugin | `plugins/rfkill/gsd-rfkill-manager.c`, `rfkill-glib.c` |
| SM-05 | system D-Bus / `org.bluez` interface contract | — |
| SM-06 | **BlueZ 5.72** | `src/adapter.c`, `src/device.c`, `src/agent.c`, `src/shared/mgmt.c` |
| SM-07 | kernel management | `net/bluetooth/mgmt.c` |
| SM-08 | **kernel SCO** | `net/bluetooth/sco.c`, `hci_conn.c` |
| SM-09 | kernel HCI core | `net/bluetooth/hci_core.c`, `hci_sync.c`, `hci_event.c` |
| SM-10 | USB transport driver | `drivers/bluetooth/btusb.c` |
| SM-11 | vendor support + quirks table | `drivers/bluetooth/btqca.c`, the `btusb` device table |
| SM-12 | firmware blobs | `linux-firmware`, QCA ROME rampatch / NVM |
| SM-13 | USB core | `drivers/usb/core/hub.c`, `driver.c`, USB PM |
| SM-14 | host controller | `xhci_hcd` |
| SM-15 | platform / ACPI / EC | power rail, warm vs cold reset, airplane mode |
| SM-16 | PipeWire BlueZ plugin | `spa/plugins/bluez5/bluez5-dbus.c`, `backend-native.c` |
| SM-17 | WirePlumber | BlueZ monitor / profile policy |

**Highest value first, in our judgement — but argue with this if you disagree:**
SM-08 (OB-02 sits on the isochronous path), SM-06 (OB-04 lives there), SM-13 and
SM-15 (OB-06 and OB-07), SM-01–SM-04 (OB-05, and S1/S2 are driven from there).

---

## 6. What we currently believe — SEALED

⚠️ **Please form and write down your own reading of §4 before opening this
section, and tell us in your deliverable whether you did.** We would rather have
an independent reading that contradicts ours than a confirmation that was
anchored by it.

Our current conclusions, stated so they can be **attacked**:

1. This USB ID matches **no entry** in the `btusb` quirks table. It therefore
   receives no vendor firmware-download path and **no `hdev->reset` callback**.
2. The HCI core has **two** watchdogs and **one** escalation path. The path that
   escalates requires an event the controller has stopped sending, so for this
   failure it is structurally unreachable. The other merely logs, fabricates a
   command credit, sends the next command, and repeats every 2 s indefinitely.
3. Nothing ever tells userspace the controller is dead: the device stays `UP`,
   and BlueZ keeps issuing commands into it.
4. We believe the driver selects USB alternate setting **1** for this device on
   the transparent/wideband path, via a fallback that logs nothing.
5. `EX-032`-class BlueZ crashes (OB-04) are a **separate failure mode** from the
   controller wedge, and we think conflating them has confused prior reports.

**If any of these is wrong, that is a more valuable result than agreement.**

---

## 7. Deliverable format

Please return **exactly these three sections**, so several reviews can be merged.

### 7.1 Findings

One block per finding, no prose essays:

```
FINDING <your-initials>-<n>
component:   SM-08
explains:    OB-02            (or "none — new observation")
claim:       <one sentence>
evidence:    <file> : <function> : <line>  @ <version/tag/commit you read>
reasoning:   <short — how the code produces the observation>
confidence:  established | probable | speculative
falsifier:   <what observation would disprove this>
```

`established` means you can point at the code path and it is not conditional on
something unverified. If you had to assume anything, it is `probable` at best.

### 7.2 Read and found nothing

**This section is required and must not be empty** if you covered more than one
component.

```
component | files read | version | what you looked for | result
```

### 7.3 What you could not settle without the machine

Anything that needs a running system, a rebuild, or hardware access. Be specific
about *what measurement* would settle it — that list becomes the operator's next
set of experiments.

---

## 8. How several reviews will be combined

Findings are merged by `component` × `explains`. Where two reviewers reach
different conclusions about the same pair, **the disagreement is kept and
published, not averaged** — a contradiction between two independent readings is
information, and resolving it prematurely destroys it.

Convergence from independent readings is treated as corroboration only when the
readings cite the same code at the same version. Two people agreeing from
different versions is not agreement.

---

## 9. Scope note

The end goal is an upstream kernel bug report and, if the evidence supports one,
a patch. Findings will be attributed. Anything you mark `speculative` will be
labelled as such if it is carried forward — we would rather publish a hedged
finding honestly than a confident one we cannot defend.
