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

The identification rests on the **manufacturer code** `0x001D` (Qualcomm) and the
companion `ath10k` Wi-Fi half of the same combo part, not on the HCI version. An earlier
draft argued that the HCI version "rules out" MediaTek and Realtek because they "would
report" particular versions. That is not a valid inference — an HCI protocol version is
not a vendor identifier, and no device-specific evidence was gathered for either vendor.
The manufacturer code alone is sufficient here, so the weaker argument is withdrawn rather
than repaired.

## 3. What the quirk restores

`BTUSB_QCA_ROME` in `driver_info` causes `btusb_probe()` to install **six** things.
Verbatim from v7.0 `drivers/bluetooth/btusb.c`:

```c
	if (id->driver_info & BTUSB_QCA_ROME) {
		data->setup_on_usb = btusb_setup_qca;
		hdev->shutdown = btusb_shutdown_qca;
		hdev->set_bdaddr = btusb_set_bdaddr_ath3012;
		hdev->reset = btusb_qca_reset;
		hci_set_quirk(hdev, HCI_QUIRK_SIMULTANEOUS_DISCOVERY);
		btusb_check_needs_reset_resume(intf);
	}
```

Of those, two are the reasons to add the ID:

1. **`hdev->reset = btusb_qca_reset`** — invoked by `hci_cmd_timeout()` on the **first**
   command timeout. `btusb_qca_reset()` falls back to `btusb_reset()`, which queues a USB
   device reset when no hardware reset GPIO is available. → **recovery**
2. **`data->setup_on_usb = btusb_setup_qca`** — rampatch and NVM firmware download
   (`qca/rampatch_usb_*.bin`, `qca/nvm_usb_*.bin`). Both are already present in
   `linux-firmware` on the affected system. → **prevention**

The other four (`shutdown`, `set_bdaddr`, `SIMULTANEOUS_DISCOVERY`, `needs_reset_resume`)
come along with the flag and are why a single build toggling `BTUSB_QCA_ROME` isolates
nothing — see the ladder in §5a.

⚠️ **`BTUSB_WIDEBAND_SPEECH` is not part of this.** An earlier draft listed it as a third
thing `BTUSB_QCA_ROME` installs. It is a separate `driver_info` bit (`BIT(21)`) tested on
its own, sixty lines further down `btusb_probe()`:

```c
	if (id->driver_info & BTUSB_WIDEBAND_SPEECH)
		hci_set_quirk(hdev, HCI_QUIRK_WIDEBAND_SPEECH_SUPPORTED);
```

The neighbouring IDs carry `BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH` — two flags, not one.
Whether to set the second is a separate decision, deliberately deferred to build D.

---

## 3a. ⚠️ Correction: this document previously described the wrong mechanism

Earlier revisions of this file claimed the quirk installs
`hdev->cmd_timeout = btusb_qca_cmd_timeout`, which waits for **five consecutive**
command timeouts before resetting. **That is wrong**, and the error invalidated the
conclusion drawn from it. Corrected 2026-08-11 after an external review, then verified
two ways.

### Verified against v7.0 source

`net/bluetooth/hci_core.c`:

```c
static void hci_cmd_timeout(struct work_struct *work)
{
	...
	bt_dev_err(hdev, "command 0x%4.4x tx timeout", opcode);
	hci_cmd_sync_cancel_sync(hdev, ETIMEDOUT);
	...
	if (hdev->reset)
		hdev->reset(hdev);
	...
}
```

**No counter, no threshold.** The reset fires on the first timeout, inside the same
handler that emits the `command tx timeout` line.

### Verified against the shipped binary on the affected machine

`tools/bt-verify-kernel-mechanism` inspects `btusb.ko` for kernel 7.0.0-28-generic:

```
btusb_qca_cmd_timeout  absent
btusb_qca_reset        PRESENT   -> hdev->reset path
```

### Why this matters: the recovery experiments did not test the patch

Every "late reset" experiment in this repository issued a userspace `USBDEVFS_RESET`
**+11 s to +33 s** after the first timeout. Under the real mechanism the kernel would
have acted at **+0 s**, synchronously with the log line those experiments trigger on.

| | Our experiments | What the patch would do |
|---|---|---|
| Trigger | watchdog tails the journal for `tx timeout` | `hci_cmd_timeout()` itself |
| Latency | +11 s … +33 s | ~0 s, same call frame |
| Call path | `USBDEVFS_RESET` → `proc_resetdevice()` → `usb_reset_device()` | `btusb_qca_reset()` → `btusb_reset()` → `usb_queue_reset_device()` |

Those are a useful proxy but **not the same experiment**. Given the evidence that the
recoverable window closes sharply — stage 1 measured at 45–66 s, and every reset inside
it still failed — the difference between +0 s and +11 s could be decisive.

> **The five failed late resets do not rule out this patch as a recovery fix. They rule
> out a reset issued eleven or more seconds late.** The patch has never been tested.

⚠️ Note also that `USBDEVFS_RESET` and `usb_queue_reset_device()` are not literally the
same path — the former calls `usb_reset_device()` directly from `proc_resetdevice()`,
the latter queues a reset on the interface. Same underlying machinery, different timing
and context. Earlier text in this repository called them identical; that was too strong.

### The experiments as they actually stand

A userspace watchdog issued `USBDEVFS_RESET` **20 s after the first HCI timeout**, which
was **33 s before** the first USB-level failure — well inside the window in which the
device still answered USB. It failed, and the chip left the bus:

```
07:24:45  Bluetooth: hci0: command tx timeout           <- first timeout; the kernel
                                                           would have reset HERE
07:25:05  watchdog: 3/3 in window -> intervening         (+20 s)
07:25:23  usb 3-3: reset full-speed USB device number 2  (+38 s)
07:25:38  usb 3-3: device descriptor read/64, error -110 (+53 s)
07:26:48  usb 3-3: USB disconnect, device number 2       (+123 s)
```

Full record: [`evidence/sessions/20260810-072445-first-real-hang/`](../evidence/sessions/20260810-072445-first-real-hang/),
including a btsnoop capture beginning one second after the first timeout.

Repeated five times at +11 s, +16 s, +20 s, +20 s and +33 s. All failed. **All of them
were late relative to what the patch would do**, which is the point of §3a.

### What survives, and what does not

| Claim | Status |
|---|---|
| The device is matched by no vendor quirks entry | ✅ verified in upstream source and the shipped binary |
| It therefore gets no reset callback and no firmware download | ✅ 287 timeouts, 0 reset attempts, 0 firmware loads across 34 boots |
| Adding the ID would prevent the hang | ❓ **untested** — every reset we tried was late relative to the kernel's |

### Two related corrections

- **Stage 1 lasts ~53 s, not ~6 h.** The earlier figure measured how long an *untouched*
  controller stayed enumerated while idle, which is not the same as how long it stays
  recoverable.
- **The trigger is not A2DP-specific.** The capture shows SCO/HFP voice traffic, then
  `Start Discovery` → `Authentication Failed (0x05)`, `Disconnect`, `Set Powered:
  Disabled`. The common factor is an audio stream torn down while active.

### Where that leaves the patch

The ID is genuinely missing, and it now matters for **two independent reasons** rather
than one:

1. **Recovery.** `hdev->reset` is never installed, so `hci_cmd_timeout()` has nothing to
   call. Untested — every experiment was 11–33 s late.
2. **Prevention.** `btusb_setup_qca()` never runs, so Linux never performs the QCA
   rampatch/NVM download for this ID. What the controller therefore *runs* is not
   established — only that this driver does not load anything into it. An earlier draft
   said it "carries factory ROM firmware forever"; that overstates what was measured, and
   is withdrawn. See [`firmware-hypothesis.md`](firmware-hypothesis.md).

The next step is the A/B build in §5a, which separates them.

### The isolated-gap evidence

`tools/bt-verify-kernel-mechanism` on the shipped `btusb.ko` (7.0.0-28-generic):

```
✓ 13d3:3491  present  BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
✓ 13d3:3496  present  BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
✓ 13d3:3501  present  BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH
✗ 13d3:3502  ABSENT
✗ 13d3:3503  ABSENT   <- this device
✗ 13d3:3504  ABSENT
```

Three consecutive IMC Networks IDs immediately below the gap carry the QCA ROME quirk;
three consecutive IDs starting at `3502` carry nothing. This is a hole in the table, not a
vendor the driver declines to support — the shape of an oversight rather than a decision.

⚠️ **`13d3:3563` is not evidence here and has been removed from this comparison.** Earlier
drafts cited it as a fourth covered neighbour. It is present in the table, but as
`BTUSB_MEDIATEK` — different silicon, and therefore not a QCA comparator at all. Its
presence says nothing about QCA coverage in either direction.

---

## 3b. The answer to that open question: earlier works

The question §3a left open — *would a reset issued during the audio teardown, before any
HCI command times out, succeed where the late one failed?* — was tested on 2026-08-10/11.

**It succeeded.**

bluetoothd sees the failure first. In the 08-10 hang it logged audio-teardown errors
**52 s** before the kernel's first `tx timeout`. The watchdog was changed to trigger on
those instead (`BT_EARLY=1`), using patterns selected by measured precision over 12
boots. Result over a 5 h 21 m boot with 145 audio/profile events:

```
EARLY intervention: 2 audio-teardown failure(s) in 90s — resetting BEFORE any HCI timeout.
  EARLY recovery SUCCEEDED
```

with **zero `tx timeout` events for the whole boot**: the stall was cleared before the
kernel would have noticed it at all.

### Consequence for this patch

Adding `13d3:3503` to the quirks table is **correct** — the device really does receive no
vendor quirks. Whether it is *sufficient* is unknown, because the reset it would install
fires at +0 s and no experiment has tested that point.

What can be said is that the recoverable window closes **sharply**:

- a reset before any HCI timeout recovered the controller (once);
- resets at +11 s … +33 s all failed (five times);
- the boundary between those lies somewhere in the first eleven seconds, and
  `hci_cmd_timeout()` fires at the very start of that interval.

⚠️ **Revised 2026-08-11.** The last bullet is now known to be wrong in general: with
`hdev->reset` installed, `hci_cmd_timeout()` *does* fire a reset — at the very moment
the first timeout is detected. What is true of this device is that the hook is never
installed, because the ID is missing. Whether a reset at +0 s lands inside the window is
exactly what §5a is designed to answer.

### ⚠️ A third incident narrows this further

On 2026-08-11 a hang provoked by **repeated connect/disconnect cycles and mode changes**
(rather than a mid-stream teardown) produced no early-warning window at all:

```
06:06:25  first HCI command timeout
06:06:36  watchdog intervened      (+11 s)   <- reset failed
06:07:09  first USB-level failure  (+45 s)
06:08:19  device left the bus     (+115 s)
06:08:38  first EARLY signal      (+133 s)   <- two minutes too late
```

Two consequences:

1. **`BT_EARLY` is not a general answer.** In two of five instrumented hangs the
   bluetoothd audio-teardown signal was unusable — arriving 133 s late in one case and
   never in another. A userspace workaround built on that signal covers only the subset
   where audio-layer trouble comes first.

   ⚠️ Whether these are genuinely *different mechanisms* is not established. The
   reproductions were ad-hoc, with no fixed procedure and no record of the exact
   actions, so a differing log signature may reflect a differing (unknown) input rather
   than a different failure path.
2. **The late-reset result is now stronger, not weaker.** This reset went out **+11 s**
   after the first timeout — near the limit of what a log-driven watchdog can do — and
   still failed. Three for three, a reset after the first HCI timeout has failed.

That sharpens the question: the recoverable window appears to close within the first
eleven seconds after the timeout. `hci_cmd_timeout()` calls `hdev->reset()` at the start
of that interval — which is precisely the point no experiment has yet occupied. Build A
in §5a puts a reset exactly there.

**Update 2026-08-12 — an early reset was finally captured, and it does not change the
above.** In the incident of that night the watchdog reset the device **133 s before** any
HCI timeout (`EX-004`). The reset worked: the device re-enumerated and the HCI stack
re-registered 315 ms later. The controller then hung anyway, 132 s afterwards, and left
the bus.

This is evidence about *durability of recovery*, not about Build A. `hdev->reset` is
invoked from the command-timeout path at **+0 s**; at 00:09:37 no timeout had occurred and
the callback would not have run. The tested point remains unoccupied, so **Build A stays in
the ladder unchanged**. What the result does do is raise Build B: recovering the controller
without re-running `btusb_setup_qca()` returned it to service in the state it was already
in, and it failed again — which is what the firmware-reload hypothesis predicts. Build B is
now the strongest *prevention* candidate, but "strongest candidate" is not "only remaining
variable", and A must still be run to know whether the +0 s position alone suffices.

The mechanism proxy holds, verified against v7.0 source: `btusb_qca_reset()` with no
`bt_en` GPIO falls through to `btusb_reset()` → `usb_queue_reset_device()`, and since
`btusb_driver` declares no `.pre_reset`/`.post_reset`, USB core unbinds and rebinds the
interface around it. The watchdog performed the same *kind* of reset the fix performs. Only
the timing differed — and in this bug, timing has been decisive every time it was measured.

⚠️ **Small n.** Two failed late resets, one successful early reset, one incident with no
early signal. Attach all three sessions:
`evidence/sessions/20260810-072445-first-real-hang/` (late reset failed),
`evidence/sessions/20260811-002156-early-mode-SUCCESS/` (early reset worked),
`evidence/sessions/20260811-060910-mode-change-hang/` (+11 s failed, no early warning).

---

## 5a. A four-step experiment — isolate the cause, do not just find a cure

**Revised twice.** The first version was a single build. The second was an A/B pair that
could not actually isolate firmware, because `BTUSB_QCA_ROME` does **not** mean "reset
plus firmware setup" — it installs six distinct behaviours:

```c
data->setup_on_usb  = btusb_setup_qca;          /* firmware download path      */
hdev->shutdown      = btusb_shutdown_qca;
hdev->set_bdaddr    = btusb_set_bdaddr_ath3012;
hdev->reset         = btusb_qca_reset;          /* the reset callback          */
HCI_QUIRK_SIMULTANEOUS_DISCOVERY;
btusb_check_needs_reset_resume(intf);
```

So "A hangs, B fixes it → firmware is the cause" is **not a valid inference**. It would
only license "something in the QCA ROME path fixes it". Isolating requires stepping
through them.

### The builds

| | What it installs | Isolates |
|---|---|---|
| **A** | `hdev->reset = btusb_qca_reset` only | immediate kernel-side recovery |
| **B** | A **+** `data->setup_on_usb = btusb_setup_qca` | QCA USB init / firmware download |
| **C** | `13d3:3503 → BTUSB_QCA_ROME` (the real candidate quirk) | everything else in the ROME path |
| **D** | C **+** `BTUSB_WIDEBAND_SPEECH` | the production candidate |

**Keep `BTUSB_WIDEBAND_SPEECH` out until D.** It changes advertised HFP wideband-speech
capability, and the reproducer involves audio profile and mode transitions — introducing
it while establishing causation would confound exactly the thing under test.

### Decision tree

```
A4: stock protocol establishes a reproducible baseline (target 5/5)
  |   NOT the 13-of-34 historical incidence — that is an observational
  |   rate from uncontrolled daily use, not a controlled reproducer, and
  |   it cannot serve as the denominator any build is compared against
  |
  +-- A works   -> immediate reset is sufficient; the +0 s vs +11 s gap is the whole story
  |
  +-- A fails
        |
        +-- B works   -> QCA USB initialisation / firmware setup is sufficient
        |
        +-- B fails
              |
              +-- C works   -> some other ROME behaviour matters (shutdown? reset_resume?
              |                SIMULTANEOUS_DISCOVERY?) — narrow it further
              |
              +-- C fails   -> the missing-ID quirk does not cure this failure path;
                               look before the first timeout
```

### Instrumentation notes

- **Build A: record which reset path actually runs.** `btusb_qca_reset()` toggles a
  `bt_en` GPIO if one exists, and only otherwise falls back to `btusb_reset()` →
  `usb_queue_reset_device()`. Expect either `Reset qca device via bt_en gpio` or
  `Resetting usb device.` Which one appears matters when comparing against the earlier
  `USBDEVFS_RESET` attempts.
- **Build B may bind and then fail at HCI open.** `setup_on_usb` is **not** run during USB
  probe — `btusb_open()` calls it when the HCI device is opened, before HCI URBs start.
  If `btusb_setup_qca()` finds an unsupported ROM version it returns `-ENODEV` and *HCI
  open/setup* fails while the USB device remains bound to `btusb`. That is a **result,
  not a failure**: capture the reported ROM version and the setup error.
  `btusb_setup_qca()` sends `QCA_GET_TARGET_VERSION`, looks the `rom_version` up in
  `qca_devices_table`, then sends `QCA_CHECK_STATUS`. Upstream v7.0 already carries Rome
  3.0 and 3.2 entries (`0x00000300`, `0x00000302`).

### Prerequisites

- **A4 — a quantified reproducer.** Not "it hung again", but a fixed protocol
  demonstrating something like **5/5 failures on stock**. Without a denominator,
  "the patched build ran for an hour" means nothing — a trap this project has fallen into
  more than once.
- **A0 — read Ubuntu's own `7.0.0-28` source** for `hci_cmd_timeout()`. Upstream v7.0
  indisputably calls `hdev->reset()` on the first timeout, and the binary confirms
  `btusb_qca_reset` is present, but after the five-timeout episode this deserves checking
  rather than inferring.

---

## 4. ⚠️ Risk, and why this must be tested before submission

**This patch is not risk-free and must not be sent upstream untested.**

`BTUSB_QCA_ROME` also enables the rampatch/NVM download path. If this module is *not* a
true ROME variant — or expects different firmware filenames — then `btusb_setup_qca()`
can fail and leave the machine with **no Bluetooth at all**, which is worse than the
current intermittent failure.

⚠️ **Corrected: this failure would not happen "during probe".** `BTUSB_QCA_ROME` sets
`data->setup_on_usb`, which is consumed later at HCI open/setup, not inside
`btusb_probe()`. The practical difference matters for how the risk presents: the device
still enumerates and binds, and the failure surfaces when the adapter is brought up. It is
recoverable by booting the previous kernel, which is why §5 pins a fallback entry rather
than treating this as unbootable-class risk.

The device is currently hard-hung and off the USB bus, so **nothing here has been
validated on hardware.** A cold power-off is required before any of §5 can be attempted.

### A more conservative first step

If the firmware download proves problematic, `BTUSB_QCA_ROME` alone (dropping
`BTUSB_WIDEBAND_SPEECH`) removes the wideband-speech confound.

⚠️ **It does not "isolate the recovery behaviour"** — an earlier draft claimed it did.
Dropping WBS removes one variable; full `BTUSB_QCA_ROME` still changes five others at once
(`setup_on_usb`, `shutdown`, `set_bdaddr`, `reset`, `SIMULTANEOUS_DISCOVERY`, plus
`needs_reset_resume`). That is build **C**, not an isolation experiment. Only builds A and
B isolate anything, and they do it by adding one field at a time rather than by removing
one flag from six.

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

# (c) THE ACTUAL TEST — run the A4 reproducer protocol, same as on stock.
#     Expect in dmesg, immediately after the first timeout:
#         Bluetooth: hci0: command 0x.... tx timeout
#         Bluetooth: hci0: Resetting usb device.        <- btusb_reset() fallback
#       or
#         Bluetooth: hci0: Reset qca device via bt_en gpio
#     followed by re-enumeration and a working controller.
#     Before the patch: timeouts, no reset attempt, then a hard hang.
```

⚠️ The expected string is `Resetting usb device.` — **not** "Multiple cmd timeouts seen",
which belonged to the `btusb_qca_cmd_timeout()` mechanism this document previously
described in error and which v7.0 does not use.

Criterion (c) is the one that matters, and only against a **quantified** baseline: run
the same protocol on stock first and record the failure rate (target 5/5). (a) and (b)
only establish that the patch did not break anything.

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
btusb's vendor quirks table, so it probes with driver_info = 0 and gets
neither hdev->reset = btusb_qca_reset nor btusb_setup_qca().

Neighbouring IMC Networks IDs are present -- 13d3:3491, 3496 and 3501
all carry BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH -- while the three
consecutive IDs 3502, 3503 and 3504 carry nothing.

Two consequences. hci_cmd_timeout() calls hdev->reset(hdev) on the first
command timeout, but hdev->reset is NULL here, so the kernel logs the
timeout and does nothing: 287 "command tx timeout" events across 34
boots with zero reset attempts. Separately, btusb_setup_qca() never
runs, so the QCA rampatch/NVM download is never performed for this ID,
though both files are present in linux-firmware on the affected system.

The observed failure follows an audio-layer state change (ungraceful
A2DP/SCO teardown, or a codec/mode switch). The controller stops
answering HCI, then ~45-66 s later stops answering USB control
transfers, then leaves the bus. Neither driver rebind, nor an xHCI port
power cycle, nor a warm reboot recovers it -- only a full power-off,
since a warm reset does not drop the M.2 power rail. The same hardware
shows no fault under Windows on the same machine.

Add the device to the QCA ROME entries so the standard command-timeout
reset path applies.

Signed-off-by: ...
```

---

## 7. Wider question for maintainers — ⛔ NOT part of the first submission

An unmatched QCA controller does not merely lose an optimisation — it can reach a state
that **no software can recover**, requiring physical intervention. That seems a harsh
consequence for a missing table entry, and the failure mode is silent: the user sees only
a Bluetooth panel that spins forever.

It *may* be worth installing a default `hdev->reset` for devices that bind through the
generic Bluetooth-class entry, so this class of missing-ID bugs is self-limiting rather
than catastrophic — every unmatched device currently leaves `hdev->reset` NULL, so
`hci_cmd_timeout()` logs and returns.

⚠️ **Do not send this with the patch.** An earlier draft argued a generic default reset is
"cheap and carries little risk". That is an assertion about every Bluetooth controller
Linux supports, made from evidence about exactly one device, and it enlarges the review
surface of a three-line device-ID addition into a change of core behaviour for all
unmatched hardware. The two must be separated:

1. establish the A/B/C/D result for `13d3:3503`
2. submit the minimal causal fix for that device
3. *then*, separately, raise generic fallback behaviour as its own discussion, with
   whatever evidence step 1 actually produced

Mixing them risks losing a well-evidenced small patch inside an under-evidenced large one.

---

## 8. Current status

| Step | State |
|---|---|
| Device is unmatched by btusb's quirks table | ✅ confirmed — upstream source and shipped binary |
| `13d3:3491/3496/3501` are `BTUSB_QCA_ROME`, `3503` is absent | ✅ verified in upstream v7.0 |
| Reset mechanism is `hdev->reset`, fired on the first timeout | ✅ source + binary (§3a) |
| Hang reproduced with full instrumentation | ✅ five incidents, HCI captures |
| **Quantified reproducer (A0/A4)** | ❌ **gate — not done** |
| Early reset (−133 s) recovers, but not durably | ✅ measured once — `EX-004` |
| **Would a reset at +0 s prevent the hang?** | ❓ **untested** — resets tried were −133 s or ≥+11 s, never at the timeout |
| Patch written | ✅ (§1, anchor needs regenerating against target tree) |
| Builds A/B/C/D | ❌ not done — see §5a |
| Checked against current mainline | ⚠️ `3503` still absent as of 2026-08-11 |
| Submitted upstream | ❌ not done |

The userspace watchdog approximates the recovery behaviour without touching the kernel,
but only approximately: it reacts +11 s to +33 s after the first timeout where the kernel
would act at +0 s. It has never recovered a controller from a late intervention. That is
evidence about *late* resets, not about this patch.

✅ **That experiment has now run** (2026-08-12, `EX-004`). The watchdog was rearmed to
trigger on the audio-teardown signature and fired **133 s before** the first HCI timeout.
The reset succeeded — the device re-enumerated and the HCI stack re-registered 315 ms
later. The controller then failed anyway 132 s afterwards and left the bus.

Read carefully, that result says: **recovery at that moment was possible, but not
durable.** It does not say a reset at +0 s fails, because +0 s was never occupied — no
timeout had happened when the watchdog fired, which is precisely why `hdev->reset` would
not have been called there either. Build A is still the experiment that answers this.

The interval it opened up is the most informative thing currently available: between
00:09:38 (stack demonstrably healthy) and 00:11:50 (first timeout), something crossed the
gap. `usbmon`, `bluetoothd -d` and 214 dynamic-debug sites are now enabled from boot
specifically to capture that window on the next reproduction.
