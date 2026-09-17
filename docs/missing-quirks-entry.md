# The missing quirks entry — what it does and does not explain

> Moved from the front page on 2026-09-18 (front-door review `FD-01`), unchanged apart
> from this banner. This was the project's first-order finding (August 2026): `13d3:3503`
> matches no entry in btusb's quirks table, so it receives neither `hdev->reset` nor the
> QCA firmware setup path. It is still true, and it now explains why **no software
> recovery exists** once the controller wedges (`BRIEF.md` §3) — not why it wedges. The
> one-line quirks patch below is **not proposed as the fix**: the reset it would install
> destroyed the device in two controlled tests, and the fault has since been located in
> the transparent-SCO alternate-setting path (`BRIEF.md` §1, `EX-033`–`EX-043`). The
> v5.11 → v5.12 dating at the end is current and is the regression candidate named in
> `BRIEF.md`.

## Established driver mismatch

`13d3:3503` is matched by no entry in btusb's vendor quirks table. It binds through the
generic USB-Bluetooth-class rule with `driver_info = 0`, so it receives **neither** of
the two things `BTUSB_QCA_ROME` provides:

- **`hdev->reset = btusb_qca_reset`** — the callback `hci_cmd_timeout()` invokes on the
  *first* command timeout (no threshold; see `net/bluetooth/hci_core.c`)
- **`btusb_setup_qca()`** — the QCA USB init path, so **no rampatch or NVM download is
  ever performed for this device through that path**

  (What firmware state the controller is actually in — pristine ROM, or something with
  persistent patch state — is not established. `btusb_setup_qca()`'s own
  `QCA_GET_TARGET_VERSION` / `QCA_CHECK_STATUS` queries would tell us; see
  [`docs/fix-proposal.md`](docs/fix-proposal.md) §5a build B.)

Three genuine QCA ROME comparators from the same ODM are covered while this one is not —
`13d3:3491`, `3496` and `3501` are all `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH` in
upstream v7.0; `3502`, `3503` and `3504` appear nowhere. Check your own kernel with
`tools/bt-verify-kernel-mechanism`.

⚠️ Numerical proximity alone proves nothing: `13d3:3563` *is* present but is
`BTUSB_MEDIATEK`. `13d3` is IMC Networks, an ODM shipping modules built around several
vendors' silicon.

Measured on the affected machine:

```
"tx timeout" events across 34 boots : 287
automatic reset attempts            :   0
```

Both the reset handler and the QCA firmware path *are* compiled into the running
`btusb.ko` (verified with `strings`). They simply never run for this device.

### Established HCI failure; unresolved USB-loss trajectory

Only the HCI-nonresponsive state is established as part of the untreated
controller-wedge fault (filed in this repository as `BT-1`, if you want to search
for it):

| Observation | Current interpretation |
|---|---|
| HCI unresponsive while USB remains healthy | established |
| USB errors/disappearance after reset, rebind or reload | observed outcome after intervention; cause unresolved |
| Untreated HCI failure progressing to USB disappearance | never observed uncensored |

⚠️ It is tempting to write "with the quirk, a reset fires within seconds and you notice
nothing but an audio dropout" — an earlier version of this file did. That is **not
established**. The one early reset ever measured did recover the controller, and it failed
again 132 seconds later (`EX-004`). A reset at the exact moment `hdev->reset` would fire —
the first HCI timeout — has still never been tested. See `docs/fix-proposal.md` §5a.

Without prompt intervention, HCI non-response persisted for 72 minutes and 6.5 hours
while the controller remained USB-enumerated. Those are censored lower bounds, not a
decay time or proof that the state lasts indefinitely.

In the intervened incidents that reached USB absence, these attempts failed:

```
usb 3-3: device descriptor read/64, error -110      # driver unbind/rebind
usb 3-3: device not accepting address 2, error -62
usb usb3-port3: attempt power cycle                 # xHCI port power cycle
usb usb3-port3: unable to enumerate USB device
```

A full shutdown has recovered the controller. Warm-reboot recovery is unmeasured: one
controller recovery across a `reboot.target` shutdown is on record, but an unlogged
power-off is not excluded (`EX-017`, `EX-019`). The claim that a warm reboot does not drop
the M.2 power rail remains an inference, not evidence.

### An earlier hypothesis about the trigger — SINCE REFUTED

> ⚠️ Kept for the record. The A2DP-teardown trigger described below does not
> hold: the transport reached IDLE five times in one boot with no SCO setup and
> no failure. See `docs/issues.md` (`BT-1`) and `EX-007`.

Tearing down an **A2DP stream mid-playback** — powering headphones off or walking out of
range while music is playing.

```
20:19:59  avdtp.c: Suspend: Connection timed out (110)
20:20:11  avdtp.c: Abort:   Connection timed out (110)
20:20:43  Bluetooth: hci0: command 0x0406 tx timeout   <-- wedged (0x0406 = HCI_Disconnect)
```

---

## A candidate fix — NOT established as the fix

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.1: the "+0 s never tested" table below
     and the BTUSB_QCA_ROME setup-failure warning are the two claims that stop
     this section overselling the patch. Any edit that removes either turns a
     hypothesis back into "the fix". -->


A one-line kernel patch — add the device to btusb's QCA ROME quirks:

```c
+	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
+						     BTUSB_WIDEBAND_SPEECH },
```

> ⚠️ **Untested — and our experiments did not test it.** Our userspace resets fired
> **+11 s to +33 s** after the first timeout and all five failed. But `hci_cmd_timeout()`
> calls `hdev->reset(hdev)` *synchronously with the timeout it reports*, with no
> threshold — so a patched kernel acts at **+0 s**. Every experiment we ran was late
> relative to the thing being proposed.
>
> | Reset issued | Result |
> |---|---|
> | **+0 s** — what the patch would do | ❓ **never tested** |
> | **+11 s … +33 s** after the first timeout | ❌ five attempts, all failed |
> | **before** any timeout, on bluetoothd's audio-teardown signal | ✅ **recovered** |
>
> The tested reset timings had different outcomes, but do not establish a one-way recovery
> deadline: a reset may recover, destabilise, or drive USB loss. The +0 s treatment is
> untested and must be scored for both benefit and harm.
>
> Sessions: [late reset failed](evidence/sessions/20260810-072445-first-real-hang/) ·
> [early reset worked](evidence/sessions/20260811-002156-early-mode-SUCCESS/) ·
> [+11 s also failed, no early warning](evidence/sessions/20260811-060910-mode-change-hang/)
>
> ⚠️ **Also untested and risky in its own right.** `BTUSB_QCA_ROME` enables the rampatch
> firmware download path; if this module is not a true ROME variant, adapter setup can
> fail and leave you with *no* Bluetooth. (Setup runs at HCI open, not at USB probe, so
> the device still enumerates — the failure appears when the adapter is brought up, and
> booting the previous kernel recovers it.) See
> [`docs/fix-proposal.md`](docs/fix-proposal.md).

**Why the missing ID matters twice.** It withholds *recovery* — `hdev->reset` is NULL, so
`hci_cmd_timeout()` logs each timeout and does nothing — **and** *prevention*, because
`btusb_setup_qca()` never runs, so Linux never performs the QCA rampatch/NVM download for
this ID. (What the controller runs instead is *not* established — only that this driver
loads nothing into it.) The first is verified three ways; the second is the
[firmware hypothesis](docs/firmware-hypothesis.md), and it is the better explanation for
why the same hardware never faults under Windows.

**Confirmed at source level.** `0x3503` does not appear anywhere in upstream
`drivers/bluetooth/btusb.c` (v7.0), which carries 78 other `0x13d3` entries — the vendor
is well covered, this product ID simply is not. The running `btusb.ko` agrees: a scan for
the little-endian `usb_device_id` pair `d3 13 03 35` finds nothing, while `d3 13 62 33`
(13d3:3362, a known entry) is found, validating the method. Ubuntu added no extra IDs —
78 in the binary, 78 in upstream.

Note `modinfo` cannot answer this: it exposes only `btusb_table`, while the quirks live
in a separate non-exported `quirks_table` matched via `usb_match_id()` (btusb.c:4046).

Longer term, the QCA9377 is a weak 2015-era part with a long history of this failure. On
most laptops it is an M.2 2230 card that swaps directly for an Intel AX200/AX210 — far
more reliable on Linux, and Wi-Fi 6 as a bonus. Check for a BIOS wireless allowlist first.

---

## Not a *recent* regression — but the driver behaviour is datable to v5.12

Tested across every kernel available on the affected machine:

| Kernel | Hangs? |
|---|---|
| 6.17.0-29 | yes |
| 6.17.0-35 | yes |
| 6.17.0-40 | yes |
| 7.0.0-28 | yes |

Four kernel versions across ten weeks and 34 boots. Rolling back to another recent
kernel does not help. Per-boot detail:
[`evidence/diagnosis/per-boot-history.txt`](evidence/diagnosis/per-boot-history.txt).

⚠️ **This heading used to read "Not a kernel regression", and that was too strong.**
The table shows the fault is not a *recent* regression. It cannot show that the
behaviour was always there, because **every kernel in it postdates the change that
matters**.

Reading `btusb.c` at ten release tags dates the relevant change between **v5.11 and
v5.12**. Through v5.11, alt setting 1 for wideband speech was a per-device opt-in
guarded by `BTUSB_USE_ALT1_FOR_WBS`, set only inside the Realtek block; any other
adapter without alt 6 got `new_alts = 0`, an error line, and no wideband speech.
v5.12 turned that opt-in into an **unconditional fallback**, so an adapter matching
no quirks entry — which `13d3:3503` does not — is placed into an isochronous
configuration it was never validated for.

The two statements are consistent: the change landed in v5.12, and the oldest kernel
tested above is 6.17. Rolling back within that range changes nothing because the
whole range is on the far side of it.

**That yields a prediction this project has not tested**: a v5.11-or-earlier kernel
should not take the alt-1 path on this hardware at all. Nobody has run it, and it is
recorded here as an open experiment rather than a result.

Confirmed on the machine rather than only in source — `EX-033`'s captured lines are
the chain itself: `hci0 evt 5` (`HCI_NOTIFY_ENABLE_SCO_TRANSP`, the transparent
branch), then `Looking for Alt no :6` and `:3` (the two probes), then silence —
because selecting alt 1 is the bare `else` and logs nothing.

---
