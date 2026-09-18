# Bug report — btusb: QCA9377 `13d3:3503` stops answering HCI after the first command issued into a transparent-SCO stream on USB alternate setting 1

**Subsystem:** `drivers/bluetooth/btusb.c` (and the HCI core's handling of a controller that never answers)
**Reporter contact:** yaroslav.voytovych@gmail.com
**Date:** 2026-09-18 (supersedes the 2026-08-11 draft, which argued for a quirks-table entry this report no longer proposes)
**Suggested recipients:** `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`
**Maintainers:** Marcel Holtmann, Luiz Augusto von Dentz
**Regression:** candidate — `BTUSB_USE_ALT1_FOR_WBS` became an unconditional fallback in v5.11 → v5.12; every kernel tested is on the far side of that change, and a ≤ v5.11 run has not been made

---

> ⛔ **This report goes out only with a patch ready to follow it.** The mechanism is not
> established and no kernel patch exists yet; sending the observation alone would ask the
> maintainers to do the investigation. Everything below is re-derivable from the public
> record at https://github.com/ivoitovych/qca9377-bt-hang (`evidence/exhibits/`, each
> exhibit carrying its extraction command, verbatim output and exit status).

## Summary

When this controller negotiates a **transparent (mSBC / wideband-speech) synchronous
link**, `btusb` finds no alternate setting 6 or 3 on the isochronous interface and falls
back to **alternate setting 1** — a **9-byte** isochronous endpoint — then streams
**27-byte** mSBC frames into it. The link comes up: `0x0428 Setup Synchronous Connection`
*is* answered, a connection handle is allocated, frames flow. **The first HCI command the
host then issues is never answered.** `hci_cmd_timeout()` fires `HCI_CMD_TIMEOUT` (2 s)
after that command; from then on the controller answers no HCI command and no USB control
transfer (`GET_DESCRIPTOR` returns `-110`), stays enumerated, survives a warm reboot in that
state, and is recovered only by removing power.

Reproduced **seven times** across three kernels (`7.0.0-29`, `-30`, `-31`), two vendors'
headsets, and both power configurations (stock autosuspend and a pinned `power/control=on`),
with alternate setting 1 read directly from `sysfs` during five of the wedges. Under
Windows 11 on the same laptop the same hardware shows no fault under deliberate repeated
use.

## What is established

**The signature, per instance.** All timestamps from the kernel journal with `btusb` and
HCI-core dynamic debug enabled from boot; `len 27 mtu 9` is `btusb`'s per-URB line and
names the endpoint size in use.

```
0x0428 answered → evt 5 (HCI_NOTIFY_ENABLE_SCO_TRANSP) → "Looking for Alt no :6" → ":3"
   → 27-byte frames on mtu 9 → FIRST HCI command issued → +2.0 s "command tx timeout"
```

| exhibit | date | kernel | power config | `len 27 mtu 9` frames | first command after link-up | setup → fault |
|---|---|---|---|---|---|---|
| `EX-033` | 08-22 | `-29` | modified | 835 | 36 ms | 2.076 s |
| `EX-036` | 08-25 | `-30` | modified | 87 | 279 ms (`0x0406`) | 2.152 s |
| `EX-037` | 09-01 | `-30` | modified | 680 | 39 ms | 2.151 s |
| `EX-038` | 09-13 | `-31` | modified | 682 | 35 ms | 2.191 s |
| `EX-040` | 09-13 | `-31` | modified | 1562 | 34 ms | 2.140 s |
| `EX-042` | 09-16 | `-31` | modified | 1595 | ~90 ms | 2.147 s |
| `EX-043` | 09-17 | `-31` | **original** | 910 | **9,650 ms** (`0x0406`) | **11.874 s** |
| survival | 09-01 | `-30` | modified | 8 | — | lived |

"Modified" is `btusb enable_autosuspend=0` plus a udev rule pinning the radio's
`power/control=on`; "original" is the Ubuntu default. It is a module parameter and a
`sysfs` write — no code differs — and `EX-043` reproduces the fault under the original.

**The interval is not a constant.** Six fast teardowns made it look like 2.15 s; `EX-043`
shows the stream running 9.65 s with zero commands in flight and no harm, and the first
command issued — `0x0406 Disconnect, reason 0x13` — dying. What is invariant is *the first
command into a running alternate-setting-1 stream is never answered*, and the interval is
that command's time plus `HCI_CMD_TIMEOUT`. Both instances where the log names the dying
command name `0x0406`.

**The alternate setting is observed, not inferred.** During five live wedges:

```
/sys/bus/usb/devices/3-3:1.1/bAlternateSetting        1
/sys/bus/usb/devices/3-3:1.1/ep_03/wMaxPacketSize     0009    Isoc
/sys/bus/usb/devices/3-3:1.1/ep_83/wMaxPacketSize     0009    Isoc
```

**CVSD is safe.** The same controller carried a CVSD link (`mtu 17`, 4,669 packets) with no
fault, and an Enhanced Setup Synchronous Connection was answered in 64.7 ms and carried a
link for 17 minutes (`EX-031`). The defect is not "this controller cannot do SCO".

**No software recovery exists.** `hci_cmd_timeout()` calls `hdev->reset()`, which is NULL
for this device (`13d3:3503` matches no `btusb` quirks entry, so it gets neither
`btusb_qca_reset` nor `btusb_setup_qca`); the GUI toggle fails with
`Opcode 0x0c03 (HCI_Reset) failed: -110` (`EX-039`); a warm reboot leaves the device
unenumerable and a power-off brings it back in about a second (`EX-027`, `EX-028`,
`EX-034`). `hci0` is never unregistered — the device stays enumerated and cannot
initialise.

**The wedge is below HCI.** USB control transfers time out once the controller has
stopped answering. At onset the transport is healthy: every URB completes with status 0,
and the first non-zero URB status appears 31.4 s later (`EX-008`).

### The untreated windows

Left entirely alone after the fault, the controller stays enumerated with **zero**
USB-layer lines for as long as anyone has waited. A natural progression to USB
disconnection has never been observed; every USB collapse in the record followed a reset,
a rebind or a driver reload.

| window | duration | ended by | was the ending ours? |
|---|---:|---|---|
| `EX-029` | **47338 s** (13 h 8 m 58 s) | power-off after 13 h unattended | no — nobody noticed |
| `EX-042` | 40324 s (11 h 12 m) | power-off | no |
| `EX-023` | 12107 s | deliberate `USBDEVFS_RESET` → USB disconnect in 11.2 s | yes |
| `EX-025` | 8884 s | ordinary shutdown — no reset, no rebind, no bus activity | no |
| `EX-016` | 4332 s | `install.sh` reloading btusb | yes |
| `EX-021` | 1837 s | operator rfkill toggle → collapse in 12.8 s | yes |

**A USB reset of the wedged controller destroys it.** Two deliberate resets, at window ages
613 s and 12107 s, both produced USB disconnection (in 85.6 s and 11.2 s) and a device that
would not enumerate until power was removed (`EX-023`, the 2026-08-15 boot). This is why
the obvious one-line fix — adding `13d3:3503` to the QCA ROME quirks so that
`hci_cmd_timeout()` installs and calls a reset — is **not** proposed by this report: the
kernel would do automatically, on the first timeout, what destroyed the device by hand.

### Two vendors, one signature

Every instrumented failure before 2026-08-15 involved one headset. It has since been
reproduced on a second vendor's device with an identical kernel-side sequence (`EX-024`),
device strings taken from the journal rather than from recollection:

| | Sennheiser `MOMENTUM 4` | Lenovo `联想thinkplus-GM2 pro` |
|---|---|---|
| `0x0428` Setup Synchronous Connection | ✔ | ✔ |
| `Looking for Alt no` (alternate-setting switch) | ✔ | ✔ |
| unanswered `0x0406` teardown | ✔ | ✔ |
| `setting interface failed (110)` | ✔ | ✔ |

Two devices is not a survey. It excludes per-peripheral idiosyncrasy as the sole
explanation; it does not show the fault is independent of the negotiated link parameters,
which both devices may share.

## Reproduction

There is no scripted reproducer, and the shape is now exact enough for a driver test:

1. pair an mSBC-capable headset and let a call or voice profile bring up a transparent
   SCO link — `btusb` logs `Looking for Alt no :6` then `:3` and selects alternate
   setting 1 silently (it is the bare `else`);
2. let it stream (`len 27 mtu 9` per URB); the stream alone does not wedge the
   controller — 9.65 s in `EX-043`;
3. issue any HCI command — a disconnect is the natural one;
4. it times out 2 s later; nothing answers afterwards; only a power-off recovers.

On this machine ordinary hands-free use provokes it within minutes to hours; `EX-040`
reached it three seconds after a headset connected. What has **not** been done: forcing
alternate setting 1 with a sustained stream on demand, or blocking it and showing survival
under identical use — the survival on record was the peripheral's choice
(`EX-031`/`EX-037` survival row), not an intervention.

## What this report does not claim

- **The mechanism.** *How* traffic on a 9-byte endpoint wedges the controller — a
  firmware state, an isochronous scheduling interaction, a controller-side buffer — is
  unknown. Correlation across seven deaths and one survival is all the record has.
- **That the missing quirks entry causes the wedge.** It explains the absence of recovery
  (`hdev->reset` NULL, no QCA firmware download through `btusb_setup_qca()`), and it is a
  real gap — `13d3:3491`, `3496` and `3501` carry `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`
  while `3502`, `3503` and `3504` carry nothing. Whether the gap is deliberate is not
  known. Adding the entry is not proposed, for the reason given above.
- **That autosuspend is involved.** An earlier belief that the pinned power policy reduced
  incidence was a deployment artefact (every "original" row predated a deploy that
  silently re-applied the policy); `EX-043` reproduces the fault under the original.
- **A single triggering opcode.** `0x0428` is answered every time; the command that dies is
  whichever comes first into the running stream. An earlier draft of this report named the
  setup command as "submitted and never answered"; that was wrong.
- **That Linux is at fault.** Windows drives this controller through the same silicon
  without failure, so hardware alone is not a sufficient explanation. It may still be a
  controller or firmware defect that only Linux's path reaches: **Linux drives this
  controller into a state that Windows does not.** Which side is at fault follows from the
  mechanism, not the other way round.

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.5: the framing above — "Linux drives
     this controller into a state that Windows does not", with fault assignment
     left to follow from evidence — is what keeps this report credible to a
     maintainer. Rewrites that blame either side up front lose that. -->

## Methodological caveat

The reproductions were not a controlled procedure. Bluetooth use was ordinary and
arbitrary — connecting and disconnecting devices, calls, playback — in no fixed sequence
and without a recorded script, so trigger attributions are inferences read backwards out
of logs and the incidents are not matched pairs. What does not depend on knowing the
trigger, and is what this report rests on: the controller's *response* — the per-instance
signature above, the `sysfs` reading, the untreated windows, the failed recoveries, the
two-vendor reproduction, and the power-off requirement — observed regardless of what
provoked it.

## The current formulation, as the project's issue register carries it

<!-- BT1-CURRENT-BEGIN -->
> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated. Later USB collapse has so far only been
> observed after a reset, rebind or driver reload; whether it belongs to the fault's
> untreated trajectory is **unresolved**.
<!-- BT1-CURRENT-END -->

## System information

```
Distribution : Ubuntu 24.04.4 LTS (noble)
Kernel       : 7.0.0-31-generic (the signature also on -29 and -30; the earlier phenotype on
               6.17.0-29/35/40 and 7.0.0-28)
BlueZ        : 5.72 (5.72-0ubuntu5.5; the daemon running since 08-25 is a rebuild of that
               source with two local NULL-dereference fixes, unrelated to this fault)
Platform     : AMD Renoir/Cezanne laptop
BT device    : usb 13d3:3503, full-speed, on xhci_hcd 0000:03:00.4 (bus 3, port 3)
Driver       : btusb, matched by the generic Bluetooth-class rule (driver_info = 0)
Companion    : ath10k_pci — qca9377 hw1.1, target 0x05020001, chip_id 0x003821ff,
               subsystem 1a3b:2b51 (AzureWave)
```

Controller identity reported over HCI:

```
Manufacturer : 0x001D (29)  = Qualcomm
Version      : 0x07         = Bluetooth 4.2
BD address   : AA:BB:CC:DD:EE:FF
Modalias     : usb:v13D3p3503d0001dcE0dsc01dp01icE0isc01ip01in00
```

## Impact

- Bluetooth becomes unusable until power is removed. A reboot does not recover it and,
  from the collapsed state, can leave the machine failing to boot until a power-button
  hold (`EX-022`, `EX-027`); a power-off recovers it in about a second (`EX-028`).
- The GNOME Bluetooth panel spins forever with no error surfaced; on 2026-08-16 that was
  the only sign a 13-hour fault had occurred (`EX-029`).
- An intervention can look harmless and not be: a daemon restart, an `hciconfig down`,
  a `modprobe -r btusb` produced zero USB-layer lines and left `hci0` present — and the
  device failed to enumerate at the next boot (`EX-034`). "No USB error followed" does not
  mean "the device is unharmed".
- The reporter observes the same pattern on several laptops with this part; that is an
  observation, not a measurement.

## What is asked

The shape of the fault is exact and the mechanism is not. What would settle it is
knowledge of the controller: whether streaming 27-byte transparent frames on a 9-byte
isochronous endpoint is a state this firmware tolerates at all, and whether the
alternate-setting-1 fallback introduced for wideband speech in v5.12 should apply to a
device that matches no quirks entry. A ≤ v5.11 kernel run on this hardware is the one
cheap experiment the reporter has not made and will make on request.

## Attachments

The exhibits named above, each with its command and verbatim output, at
https://github.com/ivoitovych/qca9377-bt-hang/tree/main/evidence/exhibits — in particular
`033`, `037` (alternate setting read live), `038`, `042`, `043`; the untreated windows
`016`, `021`, `023`, `025`, `029`; the reset outcomes `023`, `027`, `028`, `034`, `039`.
All published logs have been through `tools/sanitize-logs.sh`: MAC addresses, the Wi-Fi
access-point BSSID and filesystem UUIDs are replaced with deterministic placeholders.
