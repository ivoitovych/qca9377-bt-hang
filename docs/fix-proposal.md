# Fix proposal — btusb: add QCA9377 `13d3:3503` to the QCA ROME quirks

**Companion document:** `docs/bug-report.md`
**File:** `drivers/bluetooth/btusb.c`
**Status:** proposed — **not yet built or tested.** See §4 before submitting anything.

---

## 1. The change

Add the device to the QCA ROME group in btusb's vendor quirks table, next to the existing
ROME entries:

```diff
--- a/drivers/bluetooth/btusb.c
+++ b/drivers/bluetooth/btusb.c
@@ /* QCA ROME chipset */
 	{ USB_DEVICE(0x13d3, 0x3496), .driver_info = BTUSB_QCA_ROME |
 						     BTUSB_WIDEBAND_SPEECH },
+	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
+						     BTUSB_WIDEBAND_SPEECH },
```

⚠️ The diff hunk header is indicative. The exact anchor must be taken from the tree being
patched — the quirks table has been renamed and reordered across releases (it was
`blacklist_table` in older kernels). Regenerate with `git format-patch`; do not apply
this text literally.

---

## 2. Why `BTUSB_QCA_ROME`

| Evidence | Value | Implication |
|---|---|---|
| HCI `Manufacturer` | `0x001D` (29) | Qualcomm (Bluetooth SIG company ID) |
| HCI `Version` | `0x07` | Bluetooth 4.2 — matches QCA9377 |
| Companion Wi-Fi | `ath10k_pci: qca9377 hw1.1`, chip_id `0x003821ff` | the other half of the same combo part |
| USB vendor `13d3` | IMC Networks | standard ODM for QCA9377 M.2 modules |
| USB speed | full-speed (12 Mb/s) | consistent with ROME-era BT |

The HCI version rules out the plausible alternatives: MediaTek would report manufacturer
`0x0046` and HCI 5.2+, Realtek `0x005D`.

## 3. What the quirk restores

`BTUSB_QCA_ROME` in `driver_info` causes `btusb_probe()` to install:

1. **`hdev->cmd_timeout = btusb_qca_cmd_timeout`** — the reason for this patch.
   After 5 consecutive HCI command timeouts it calls `usb_queue_reset_device()`,
   resetting the controller while it is still responsive on USB.
2. **`btusb_setup_qca()`** — rampatch and NVM firmware download
   (`qca/rampatch_usb_*.bin`, `qca/nvm_usb_*.bin`). Both are already present in
   `linux-firmware` on the affected system.
3. **`BTUSB_WIDEBAND_SPEECH`** — mSBC wideband speech for HFP.

Item 1 was the motivation for this patch. **A direct test now casts doubt on whether it
would be sufficient — see §3a.**

---

## 3a. ⚠️ The central assumption failed its first test

This proposal was written on the assumption that a USB reset during stage 1 recovers the
controller. On 2026-08-10 that was tested directly and **it did not**.

A userspace watchdog issued `USBDEVFS_RESET` — the same operation
`usb_queue_reset_device()` performs, through the same kernel path — **20 s after the
first HCI timeout**, which was **33 s before** the first USB-level failure. It was well
inside the window in which the device still answered USB. The reset failed and the chip
went on to leave the bus:

```
07:24:45  Bluetooth: hci0: command tx timeout           <- first timeout
07:25:05  watchdog: 3/3 in window -> intervening         (+20 s)
07:25:23  usb 3-3: reset full-speed USB device number 2  (+38 s)
07:25:38  usb 3-3: device descriptor read/64, error -110 (+53 s)
07:26:48  usb 3-3: USB disconnect, device number 2       (+123 s)
```

Full record: [`evidence/sessions/20260810-072445-first-real-hang/`](../evidence/sessions/20260810-072445-first-real-hang/),
including a btsnoop capture beginning one second after the first timeout.

`btusb_qca_cmd_timeout()` fires on the 5th consecutive timeout — roughly the same moment
— and does roughly the same thing. **There is therefore no evidence that this patch
would have prevented the hang.**

### What survives, and what does not

| Claim | Status |
|---|---|
| The device is matched by no vendor quirks entry | ✅ verified in upstream source and the shipped binary |
| It therefore gets no `cmd_timeout` handler and no firmware download | ✅ 287 timeouts, 0 reset attempts, 0 firmware loads across 34 boots |
| Adding the ID would prevent the hang | ❌ **not supported** — the one direct test failed |

### Two related corrections

- **Stage 1 lasts ~53 s, not ~6 h.** The earlier figure measured how long an *untouched*
  controller stayed enumerated while idle, which is not the same as how long it stays
  recoverable.
- **The trigger is not A2DP-specific.** The capture shows SCO/HFP voice traffic, then
  `Start Discovery` → `Authentication Failed (0x05)`, `Disconnect`, `Set Powered:
  Disabled`. The common factor is an audio stream torn down while active.

### Where that leaves the patch

Still worth reporting: a device silently receiving no vendor quirks is a real defect,
and the reporter has seen the same behaviour on several laptops. But it should be
submitted as *"this device is unmatched"*, not *"this fixes the hang"* — and the failed
reset should be stated plainly, because a maintainer will want to know that the obvious
remedy was tried and did not work.

Open question for maintainers: would a reset issued **earlier** — during the audio
teardown, before any HCI command times out — succeed where this one failed? If the chip
is already unrecoverable by the time the first command times out, then `cmd_timeout` is
structurally too late for this failure mode, whatever device IDs are in the table.

---

## 4. ⚠️ Risk, and why this must be tested before submission

**This patch is not risk-free and must not be sent upstream untested.**

`BTUSB_QCA_ROME` also enables the rampatch/NVM download path. If this module is *not* a
true ROME variant — or expects different firmware filenames — then `btusb_setup_qca()`
can fail during probe and leave the machine with **no Bluetooth at all**, which is worse
than the current intermittent failure.

The device is currently hard-hung and off the USB bus, so **nothing here has been
validated on hardware.** A cold power-off is required before any of §5 can be attempted.

### A more conservative first step

If the firmware download proves problematic, `BTUSB_QCA_ROME` alone (dropping
`BTUSB_WIDEBAND_SPEECH`) isolates the recovery behaviour from the audio-codec change and
narrows the variables.

---

## 5. Validation plan

Out-of-tree first — never patch the distribution kernel directly.

```bash
# 0. cold power-off first, so the controller is alive again

# 1. sources for the running kernel
sudo apt install linux-source-$(uname -r | cut -d- -f1) build-essential
#    or: git clone git://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git

# 2. apply the change to drivers/bluetooth/btusb.c

# 3. build btusb alone against the running kernel's headers
make -C /lib/modules/$(uname -r)/build M=$PWD/drivers/bluetooth modules

# 4. swap it in
sudo systemctl stop bluetooth
sudo modprobe -r btusb
sudo insmod drivers/bluetooth/btusb.ko
sudo systemctl start bluetooth
```

### Success criteria

```bash
# (a) the QCA firmware path now runs — absent in every log before the patch
dmesg | grep -iE "rampatch|nvm_usb|qca"
#     expect: "hci0: using rampatch file: qca/rampatch_usb_00000302.bin"

# (b) the adapter still works
bluetoothctl show          # Powered: yes
hciconfig -a               # local name reads back without timeout
#     then pair and stream audio to a known device

# (c) THE ACTUAL TEST — reproduce the original trigger:
#     start playback, then kill the headset mid-stream.
#     Expect in dmesg:
#         Bluetooth: hci0: Multiple cmd timeouts seen. Resetting usb device.
#     followed by re-enumeration and a working controller.
#     Before the patch: timeouts forever, then a hard hang.
```

Criterion (c) is the one that matters. (a) and (b) only establish that the patch did not
break anything.

### Making it survive kernel updates

If it works, package it with DKMS rather than reinstalling by hand — this host tracks
HWE and has 24 kernels installed, so manual rebuilds are not sustainable.

---

## 6. Before submitting upstream

1. **Check current mainline first.** The ID may already have been added since 7.0:
   ```bash
   git log --oneline -S "0x3503" -- drivers/bluetooth/btusb.c
   grep -n "13d3, 0x3503" drivers/bluetooth/btusb.c
   ```
2. ~~Confirm against the actual quirks table~~ — **done**. `0x3503` is absent from
   upstream `btusb.c` (v7.0) and from the shipped `btusb.ko` binary (byte-scan for
   `d3 13 03 35`, method validated against `d3 13 62 33`). Still worth re-checking
   against current master before sending, in case it has been added since.
3. **Verify the ODM part.** `13d3:3503` is an IMC Networks module ID; confirm it is a
   QCA9377 across vendors, since the same USB ID can be reused.
4. Run `scripts/checkpatch.pl --strict` on the generated patch.
5. Send with `scripts/get_maintainer.pl` output — `linux-bluetooth@vger.kernel.org`,
   Marcel Holtmann, Luiz Augusto von Dentz.

### Suggested commit message

```
Bluetooth: btusb: Add QCA9377 13d3:3503 to the QCA ROME quirks

The QCA9377 Bluetooth controller with USB ID 13d3:3503 is not matched by
btusb's vendor quirks table, so it probes with driver_info = 0 and never
gets hdev->cmd_timeout = btusb_qca_cmd_timeout().

Without that handler nothing resets the controller when its firmware
stalls. On the affected system a stall provoked by an ungraceful A2DP
teardown produced 287 "command tx timeout" events across 34 boots and
zero reset attempts. The host keeps submitting commands to a stalled
controller for hours, and the firmware degrades from HCI-unresponsive
(recoverable by a USB reset) to USB-unresponsive, at which point the
device drops off the bus. Neither driver rebind, nor an xHCI port power
cycle, nor a warm reboot recovers it -- only a full power-off does,
since a warm reset does not drop the M.2 power rail.

Add the device to the QCA ROME entries so the standard command-timeout
reset path applies.

Signed-off-by: ...
```

---

## 7. Wider question for maintainers

An unmatched QCA controller does not merely lose an optimisation — it can reach a state
that **no software can recover**, requiring physical intervention. That seems a harsh
consequence for a missing table entry, and the failure mode is silent: the user sees only
a Bluetooth panel that spins forever.

It may be worth installing a generic `cmd_timeout` handler for devices that bind through
the generic Bluetooth-class entry. A USB reset of a controller that has already missed
several command completions is cheap and carries little risk, and it would make this
entire class of missing-ID bugs self-limiting instead of catastrophic.

---

## 8. Current status

| Step | State |
|---|---|
| Device is unmatched by btusb's quirks table | ✅ confirmed — behavioural, upstream source, and shipped binary |
| Trigger reproduced with instrumentation | ✅ 2026-08-10, full HCI capture |
| **Would the patch prevent the hang?** | ❌ **no evidence — the equivalent reset failed (§3a)** |
| Patch written | ✅ (§1, anchor needs regenerating against target tree) |
| Built out-of-tree | ❌ not done |
| Tested on hardware | ❌ not done |
| Checked against current mainline | ❌ not done |
| Submitted upstream | ❌ not done — **and the claim must be narrowed first (§3a)** |

The userspace watchdog reproduces the same recovery behaviour without touching the
kernel. It is active, it detects the stall in ~20 s — and on the one occasion it has
faced a real hang, **it did not recover the controller either**, for the same reason the
patch is now in doubt. Both approaches rest on the same assumption, and that assumption
has failed once under measurement.

Next experiment worth running: intervene on the *audio-teardown* signature (AVDTP/SCO
errors in bluetoothd) rather than on `tx timeout`, i.e. reset before the first HCI
command times out. If that recovers the chip, `cmd_timeout` is simply too late a hook
for this failure mode and the finding is worth far more to maintainers than a device-ID
addition.
