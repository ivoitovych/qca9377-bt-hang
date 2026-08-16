# Bug report — btusb: QCA9377 `13d3:3503` is absent from the QCA ROME quirks, so it gets neither firmware setup nor a reset callback

**Subsystem:** `drivers/bluetooth/btusb.c`
**Reporter contact:** yaroslav.voytovych@gmail.com
**Date:** 2026-08-11
**Suggested recipients:** `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`
**Maintainers:** Marcel Holtmann, Luiz Augusto von Dentz
**Regression:** No — reproduced on 6.17.0-29, 6.17.0-35, 6.17.0-40 and 7.0.0-28, over 10 weeks

---

> ⛔ **Do not send this without working through
> [`pre-submission-checklist.md`](pre-submission-checklist.md).** It collects every
> outstanding blocker — unmet evidence gates, content that must be excluded, and a
> deferred privacy cleanup of git history — that would otherwise be found only by chance.

> 🔬 **Under active revision.** The hardware is reported to work flawlessly under Windows
> on this same laptop. That points at a cause this report does not yet cover: the device
> also never receives its **firmware patch** under Linux, because the same missing quirks
> entry that skips the `cmd_timeout` handler also skips `btusb_setup_qca()`. See
> [`firmware-hypothesis.md`](firmware-hypothesis.md). Do not submit this report until
> that line of investigation is resolved — it may change the framing substantially.

## Summary

**A QCA9377 (`13d3:3503`) is matched by no entry in btusb's quirks table.** It probes
with `driver_info = 0`, and therefore receives **neither** of the two things
`BTUSB_QCA_ROME` would give it:

1. **`hdev->reset = btusb_qca_reset`** — the callback `hci_cmd_timeout()` invokes on the
   first HCI command timeout. Without it, `hdev->reset` is NULL and nothing is attempted.
2. **`data->setup_on_usb = btusb_setup_qca`** — rampatch and NVM firmware download.
   Without it, Linux never performs the QCA rampatch/NVM download for this ID. What the
   controller runs instead is not established by this report; only that this driver loads
   nothing into it.

The aggregate retained history contains **287 HCI command timeouts across 34 boots and
four kernel versions**, with no reset-like or firmware-load message found by the original
scan. Those unpaired counts are context, not proof of the per-device mechanism; the missing
QCA match and its consequences are established separately from source and module inspection.
Thirteen of the 34 boots recorded the historical hang classification. In the documented
USB-absent incidents, USB loss followed an intervention and a full power-off recovered the
controller. A deliberate warm-reboot recovery trial has not been performed.

The gap is isolated rather than a vendor the driver declines to support. In the shipped
`btusb.ko`, `13d3:3491`, `3496` and `3501` all carry
`BTUSB_QCA_ROME | BTUSB_WIDEBAND_SPEECH`, while the three consecutive IDs `3502`, `3503`
and `3504` carry nothing.

(`13d3:3563` is also present in the table but is **not** a comparator: it is
`BTUSB_MEDIATEK`, different silicon. Earlier drafts of this report cited it as a fourth
QCA neighbour, which was wrong.)

### The failure

<!-- BT1-CURRENT-BEGIN -->
> The controller sometimes enters a non-responsive HCI state during synchronous-audio link
> transitions, while remaining USB-enumerated. Later USB collapse has so far only been
> observed after a reset, rebind or driver reload; whether it belongs to the fault's
> untreated trajectory is **unresolved**.
<!-- BT1-CURRENT-END -->

The onset is followed within seconds by `hci0: command tx timeout`. From that point the
controller answers no HCI command, while remaining USB-enumerated and initially error-free.

⚠️ Earlier revisions continued "…45–66 s later it stops answering USB control transfers
and leaves the bus", as the fault's trajectory. That figure is **withdrawn**: every
observation behind it had one of our own USB resets between the HCI timeout and the USB
collapse, and the 29–121 s clustering is the watchdog's reaction time, not the device's
survival time (`EX-018`). In the observations with no intervention the controller stayed
enumerated with no USB-level error for 1 h 12 m and 6 h 26 m, right-censored by us
(`EX-016`). Whether the USB collapse belongs to the fault's untreated trajectory at all
is **unresolved** — it has only ever been observed downstream of a reset, rebind or
driver reload.

**The same hardware in the same laptop shows no fault under Windows 11** under deliberate
repeated connect/disconnect/mode-change cycles, tested 2026-08-11. Hardware alone is
therefore not a sufficient explanation; some OS/driver/firmware/command-sequence
difference is necessary to produce it.

<!-- REVIEWED-KEEP 2026-08-15T1752Z §1.5: the framing below — "Linux drives
     this controller into a state that Windows does not", with fault assignment
     left to follow from evidence — is what keeps this report credible to a
     maintainer. Rewrites that blame either side up front lose that. -->
This is deliberately *not* stated as "the hardware is fine and Linux is broken". Windows
may upload different firmware, initialise the controller differently, choose different
synchronous-connection parameters, reset the device at a different point, or leave a
vendor register in another state. The defect may well live in the controller or its
firmware, with Linux simply being the environment that reaches the state which exposes it.
The accurate formulation, and the more useful one, is: **Linux drives this controller into
a state that Windows does not.** Which of the two is at fault follows from that, not the
other way round.

### What has and has not been tested

A userspace watchdog issued `USBDEVFS_RESET` at **+11 s, +16 s, +20 s, +20 s and +33 s**
after the first timeout. None restored HCI service, and USB loss followed. After one reset
issued *before* any timeout, on a bluetoothd audio-teardown signal, the controller answered;
that intervention censored whether a failure was imminent.

⚠️ **Those experiments do not test the proposed patch.** `hci_cmd_timeout()` calls
`hdev->reset(hdev)` unconditionally on the **first** timeout, with no threshold — so a
patched kernel would act at **+0 s**, synchronously with the log line the watchdog reacts
to. Every post-timeout experiment above was 11 s or more late. The +0 s point is **unknown**:
an immediate reset may recover the controller or may contribute to later USB loss, so both
benefit and harm must be measured.

See §"What the missing entry does and does not explain" for the mechanism, and
[`firmware-hypothesis.md`](firmware-hypothesis.md) for the prevention side.

In every incident where the chip reached the USB-unresponsive state and left the bus,
that state could not be cleared by any software means — not driver rebind, not an xHCI
port power-cycle. A full power-off recovers it. (Whether a warm reboot can is untested;
the common "the M.2 rail is not dropped" explanation is an inference, not a
measurement — `EX-017`, `EX-019`. And whether the USB collapse occurs at all without a
reset in between is the open question above.)

> ⚠️ **Confidence.** Finding 1 is verified three ways and is solid. Finding 2 rests on
> five failed late resets (+11 s, +16 s, +20 s, +20 s and +33 s — the same five this
> report's "What has and has not been tested" section counts) and one successful early
> reset. Offered as a hypothesis with evidence, not a settled result. Full logs for the
> instrumented sessions are attached. *(An earlier revision of this note said "two
> failed late resets" and "all three" — a count frozen when it was written and never
> updated as the record grew to five; corrected, review 2026-08-15T1752Z §1.5.)*
>
> ⚠️ **An important limitation.** The bluetoothd warning is **not always available**, and
> its lead time varies enormously. Across five instrumented hangs:
>
> | Trigger | Early-warning lead |
> |---|---|
> | audio teardown | −52 s |
> | audio teardown (the one recovery) | enough for ≥2 signals |
> | connect/disconnect + mode changes | **+133 s** — arrived after the controller had gone |
> | "a few manipulations" | −7 s |
> | light use, 2 min into a fresh boot | **none at all** |
>
> Two of five had no usable warning. Watching bluetoothd is therefore not a general
> substitute for a kernel-level mechanism — it covers roughly the teardown-triggered
> subset. A −7 s case also bounds how slow any mechanism can be.

---

## System information

```
Distribution : Ubuntu 24.04.4 LTS (noble)
Kernel       : 7.0.0-28-generic #28~24.04.1-Ubuntu SMP PREEMPT_DYNAMIC x86_64
              (also reproduced on 6.17.0-29, 6.17.0-35 and 6.17.0-40-generic)
BlueZ        : 5.72
Platform     : AMD Renoir/Cezanne laptop
BT device    : usb 13d3:3503, full-speed, on xhci_hcd 0000:03:00.4 (bus 3, port 3)
Driver       : btusb
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

---

## ⚠️ Methodological caveat — read before weighing the comparisons

**The reproductions were not a controlled procedure.** The operator's Bluetooth actions
were ad-hoc and essentially arbitrary: connecting and disconnecting devices, toggling
modes, playing audio, in no fixed sequence and without recording the exact steps.

Consequences for what follows:

- **Trigger attributions are inferences from logs**, not from a known script. Where this
  report says a hang followed "an A2DP teardown" or "connect/disconnect cycles", that is
  read backwards out of bluetoothd's output. The actual keystrokes are unknown.
- **The incidents are not matched pairs.** Differences between them may reflect different
  (unrecorded) actions rather than different mechanisms. Any statement here of the form
  "trigger X behaves differently from trigger Y" should be read as *"these two log
  signatures differ"*, not as a controlled comparison.
- **Not reproducible on demand.** No deterministic reproducer exists. Frequency and
  timing therefore cannot be treated as measurements of the fault, only of this operator's
  usage.

What this does **not** weaken, because none of it depends on knowing the trigger:

- the device is matched by no entry in btusb's quirks table (verified in source and binary)
- 287 command timeouts across 34 boots with zero reset attempts
- **every reset issued after the first HCI timeout failed, five for five**
- with no intervention, stage 1 persisted 1 h 12 m and 6 h 26 m with no USB-level
  error (`EX-016`, `EX-018`); the once-quoted "45–66 s to USB collapse" was our own
  watchdog's reaction time and is withdrawn

Those are properties of the controller's response, observed regardless of what provoked it.

---

## What provokes it (approximate — see the caveat above)

**There is no deterministic reproducer.** What is known is that ad-hoc Bluetooth activity
provokes it fairly readily on this machine: connecting and disconnecting classic (BR/EDR)
audio devices, toggling modes, starting and interrupting playback. Devices involved:
Sennheiser MOMENTUM 4, Lenovo thinkplus GM2 pro, Tronsmart T8.

It occurred in **13 of 34 boots**, and in one instrumented case **two minutes into a
freshly power-cycled boot** under light use — so it needs neither prolonged uptime nor
accumulated state.

The clearest logged sequence, from the first instrumented hang, was an ungraceful A2DP
teardown:

1. audio streaming to a paired device
2. the device goes away mid-stream (powered off / out of range) rather than disconnecting
   cleanly
3. AVDTP `Suspend` and `Abort` time out
4. ~30 s later the host issues `HCI_Disconnect` (0x0406), which never completes

⚠️ That sequence is **reconstructed from logs**, not from a recorded procedure, and other
hangs showed no AVDTP involvement at all — in two of five, bluetoothd said nothing before
the controller stalled. Treat step 1–4 as one observed path, not as *the* trigger.

---

## Observed behaviour

### Stage 1 — firmware stalls, USB still healthy

The first two lines are **bluetoothd**, the rest **kernel** — the stream below is interleaved from both.

```
Aug 09 20:19:59 bluetoothd[36567]: profiles/audio/avdtp.c:cancel_request() Suspend: Connection timed out (110)
Aug 09 20:20:11 bluetoothd[36567]: profiles/audio/avdtp.c:cancel_request() Abort:   Connection timed out (110)
Aug 09 20:20:43 kernel: Bluetooth: hci0: command 0x0406 tx timeout      <-- firmware wedges
Aug 09 20:20:49 kernel: Bluetooth: hci0: setting interface failed (110)
Aug 09 20:33:51 kernel: Bluetooth: hci0: link tx timeout
Aug 09 20:33:51 kernel: Bluetooth: hci0: killing stalled connection 11:11:11:11:11:01
Aug 10 02:21:21 kernel: Bluetooth: hci0: Opcode 0x0c3a failed: -110
Aug 10 02:21:23 kernel: Bluetooth: hci0: Opcode 0x2005 failed: -110
Aug 10 02:21:25 kernel: Bluetooth: hci0: Opcode 0x200b failed: -110
```

`hciconfig` at this point — note the interface still claims `UP RUNNING`:

```
$ hciconfig -a
Can't read local name on hci0: Connection timed out (110)
hci0:   Type: Primary  Bus: USB
        BD Address: AA:BB:CC:DD:EE:FF
        UP RUNNING PSCAN
        RX bytes:12490523  acl:2838 sco:11 events:1743003 errors:0
        TX bytes:1130481955 acl:1722894 sco:7045 commands:7937 errors:0
```

**`errors:0` in both directions.** The USB transport is entirely healthy; the chip simply
never produces an event in reply. This is precisely the situation `hdev->reset` exists to
handle — and on this device it is NULL, so nothing is attempted.

### USB loss after intervention — not an established second stage

In this incident, the controller remained HCI-nonresponsive and USB-enumerated for roughly
six hours. The operator then unbound/rebound the device; after that intervention it stopped
answering USB control transfers. The following recovery attempts failed. This chronology
does not establish that the untreated controller would have left the bus:

```
# unbind / rebind the USB device
$ echo 3-3 > /sys/bus/usb/drivers/usb/unbind ; echo 3-3 > /sys/bus/usb/drivers/usb/bind
usb 3-3: reset full-speed USB device number 2 using xhci_hcd
usb 3-3: device descriptor read/64, error -110
usb 3-3: device descriptor read/64, error -110
usb 3-3: device not accepting address 2, error -62
usb 3-3: USB disconnect, device number 2

# kernel's own retry loop (device numbers 4 through 11)
xhci_hcd 0000:03:00.4: Timeout while waiting for setup device command
usb 3-3: WARN: invalid context state for evaluate context command.
usb usb3-port3: unable to enumerate USB device

# xHCI port power cycle
$ echo 1 > /sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable ; sleep 5
$ echo 0 > /sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/disable
usb usb3-port3: attempt power cycle
<no enumeration>
```

The device is now absent from the bus entirely:

```
$ lsusb -s 3:
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 003 Device 003: ID 2808:c652 FocalTech FocalTech Fingerprint Device
$ ls /sys/class/bluetooth/
<empty>
```

**Control:** the FocalTech fingerprint reader at `3-4`, on the same xHCI controller,
remained fully functional throughout. The host controller and bus are fine — the fault is
confined to the QCA9377 Bluetooth silicon.

A full power-off recovered it. Whether a warm reboot can do so is unmeasured; the M.2-rail
explanation is an untested hardware inference (`EX-017`, `EX-019`).

---

## Root cause analysis

`hci_cmd_timeout()` in `net/bluetooth/hci_core.c` (v7.0) logs the timeout and then calls
the driver's reset callback **immediately, with no threshold**:

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

For a device matched as `BTUSB_QCA_ROME`, `btusb_probe()` installs
`hdev->reset = btusb_qca_reset`, which falls back to `btusb_reset()` and queues a USB
device reset when no hardware reset GPIO is present.

**On this device `hdev->reset` is NULL**, so the `if` is simply not taken: the kernel
logs the timeout and does nothing. That is the mechanism behind 287 timeouts with zero
reset attempts.

> **Correction.** Earlier revisions of this report described
> `hdev->cmd_timeout = btusb_qca_cmd_timeout` with a five-consecutive-timeout counter.
> That mechanism is not what v7.0 uses, and the error materially affected the conclusions
> drawn from our experiments. Corrected after external review and verified two ways: the
> source above, and `tools/bt-verify-kernel-mechanism`, which finds `btusb_qca_reset`
> present and `btusb_qca_cmd_timeout` absent in the shipped module.

### Evidence that it is not installed for this device

**1. The handler never fired, across 287 timeouts in 34 boots.**

```
total "tx timeout" events across 34 retained boots : 287
occurrences of "Multiple cmd timeouts" / "Resetting usb device" : 0
```

**2. The QCA firmware download path never ran, in any boot.**
No `using rampatch file: qca/rampatch_usb_*.bin`, no `qca/nvm_usb_*`, no ROME patch
messages. `btusb_setup_qca()` is evidently never reached.

**3. Both code paths *are* present in this build**, so their absence reflects device
matching, not kernel configuration:

```
$ zstd -dc /lib/modules/7.0.0-28-generic/kernel/drivers/bluetooth/btusb.ko.zst \
    | strings | grep -E "Resetting usb device|rampatch|nvm_usb"
%s: Resetting usb device.
qca/rampatch_usb_%08x.bin
%s: using rampatch file: %s
qca/nvm_usb_%08x
```

The device consequently binds via the generic Bluetooth-class entry
(`bInterfaceClass=E0, SubClass=01, Protocol=01`) with `driver_info = 0`, receiving no
vendor quirks at all.

**4. Confirmed against the source and the shipped binary.**
`0x3503` appears nowhere in upstream `drivers/bluetooth/btusb.c` (v7.0), a file that
carries 78 other `0x13d3` entries. Scanning the distribution's own `btusb.ko` for the
little-endian `usb_device_id` byte pair `d3 13 03 35` finds no match, while
`d3 13 62 33` (13d3:3362, `BTUSB_ATH3012`) is found — validating the scan. The binary
and upstream both contain exactly 78 `13d3` entries, so no distro patch adds it.

> ⚠️ **Note on `modinfo`.** `modinfo btusb` exposes only `btusb_table`
> (the `MODULE_DEVICE_TABLE`); the vendor quirks live in a separate, non-exported table
> consulted via `usb_match_id()` inside `btusb_probe()`. The absence of a `13d3:3503`
> alias in `modinfo` output is therefore **not** by itself proof of a missing quirks
> entry. The behavioural observations above are corroborated by the direct
> source and binary checks in item 4.

### What the missing entry does and does not explain

Without it there is no back-pressure of any kind: `hdev->reset` is NULL, the host keeps
submitting commands to a stalled controller, and nothing ever tries to clear the
condition. Separately, `btusb_setup_qca()` never runs, so the firmware is never patched.

**What we have NOT shown is whether installing the reset callback would help.**

On 2026-08-10 a hang was reproduced with instrumentation running. A userspace watchdog
issued `USBDEVFS_RESET` **20 s after the first HCI timeout**, which was **33 s before**
the first USB-level failure. The reset failed and the device dropped off the bus:

```
07:24:45  Bluetooth: hci0: command tx timeout          <- first timeout
07:25:05  watchdog: 3/3 in window -> intervening        (+20 s)
07:25:23  usb 3-3: reset full-speed USB device number 2 (+38 s)
07:25:38  usb 3-3: device descriptor read/64, error -110 (+53 s)
07:26:48  usb 3-3: USB disconnect, device number 2      (+123 s)
```

⚠️ A patched kernel would have called `btusb_qca_reset()` **at 07:24:45**, in the same
handler that printed that first line — 20 s earlier than the watchdog managed. The two
are not equivalent, and this experiment therefore says nothing about the patch.

### The positive control: an earlier reset succeeded

The obvious follow-up was to try the same reset *earlier*. bluetoothd sees the failure
before the kernel does — in the 08-10 hang it logged audio-teardown errors **52 s**
before the first `tx timeout`:

```
07:23:53  bluetoothd: Unable to get Hands-Free Voice gateway SDP record: Host is down
07:24:36  bluetoothd: No matching connection for device
07:24:41  bluetoothd: a2dp.c:a2dp_config() avdtp_close failed
07:24:45  kernel:     Bluetooth: hci0: command tx timeout        <- a patched kernel resets HERE
```

The watchdog was changed to reset on those bluetoothd signals instead. On the boot of
2026-08-10 18:56 — 5 h 21 m, 145 audio/profile events, the failure path entered 6 times:

```
EARLY intervention: 2 audio-teardown failure(s) in 90s — resetting BEFORE any HCI timeout.
  EARLY recovery SUCCEEDED
```

**Zero `tx timeout` events occurred that entire boot.** The early reset did not just
recover the controller after a stall; it kept the stall from ever reaching the point
where the kernel would have noticed at all.

### What this suggests

| Claim | Status |
|---|---|
| The device is matched by no vendor quirks entry | ✅ verified in upstream source and shipped binary; 287 timeouts / 0 resets / 34 boots |
| A reset **11–33 s after** the first HCI timeout recovers it | ❌ five attempts, all failed |
| A reset **before** the first HCI timeout recovers it | ✅ tested once — succeeded |
| A reset **at +0 s**, i.e. what a patched kernel would do | ❓ **never tested** |
| Adding the device ID would fix the hang | ❓ **open** — see the row above |

The tested timings have different observed outcomes, but they do not establish a
one-directional recovery deadline. A reset may recover the controller, leave it unstable,
or contribute to the later USB collapse. `hci_cmd_timeout()` calls `hdev->reset()`
synchronously with the timeout it reports, so a patched kernel occupies the untested +0 s
point and must be scored for both recovery and harm.

⚠️ **Small n throughout.** Five failed late resets, one successful early reset, two hangs
with no early warning at all. The incidents were not controlled reproductions (see the
methodological caveat above). Treat all of this as evidence, not proof.

Two further corrections from the same session, both to assumptions stated earlier in
this report:

- **No recovery deadline is established.** The 53 s interval ended in our intervention;
  the ~6 h interval was another censored lower bound while the controller stayed
  enumerated. Neither measures how long the untreated state remains recoverable.
- **The trigger is not A2DP-specific.** The HCI capture shows hundreds of `SCO Data TX`
  packets (HFP voice), then `Start Discovery` returning `Authentication Failed (0x05)`,
  a `Disconnect`, and `Set Powered: Disabled`. The common factor is an active audio
  stream being torn down, not A2DP as such. That `Authentication Failed` status also
  appears in the original logs and now looks like a symptom of the stalling controller
  rather than a genuine authentication problem.

Maintainers are better placed to say whether an earlier or different reset — issued
during the audio teardown, before any HCI command times out — would succeed where this
one did not.

---

## Impact

- Bluetooth becomes unusable; a full power-off has recovered it. Warm-reboot behavior is
  unresolved (`EX-017`, `EX-019`).
- GNOME Settings shows a Bluetooth panel spinning forever (the MGMT request never
  completes), with no error surfaced to the user.
- Occurred in 13 of 34 consecutive boots under normal daily use.
- The reporter observes the same pattern on **multiple different laptops**, suggesting
  either this device ID is widespread or other IDs are similarly unmatched.

---

## Proposed fix

Add `13d3:3503` to btusb's QCA ROME quirks entries. See `docs/fix-proposal.md` for the patch,
its justification and the validation plan.

A broader question for maintainers, separate from this device-specific report, is whether
generic-class devices should receive a default timeout reset. The present evidence cannot
justify that change: even on this one controller the sign of a reset at +0 s is unmeasured,
and no claim about safety across other controllers follows from these incidents.

---

## Workaround in use

A userspace watchdog reproduces the missing handler: it tails the kernel log, and after
3 controller timeouts within 60 s issues `USBDEVFS_RESET` on the device, escalating to
USB unbind/bind if that is insufficient. Additionally, USB autosuspend is disabled for
the device (`btusb enable_autosuspend=0` plus a udev rule pinning `power/control=on`).
That setting is an unproven mitigation variable, not an established trigger mechanism.

Both are documented in `docs/changes-applied.md`. Effectiveness measurement is ongoing.

---

## Attachments to include when filing

- `evidence/baseline/kernel-boot0.sanitized.log` — full kernel log for the failing boot
- `evidence/baseline/bluetoothd-boot0.sanitized.log` — corresponding bluetoothd log
- `docs/investigation.md` — complete investigation with all measurements
- `evidence/baseline/baseline.tsv` — per-boot failure counts across 34 boots

✅ **The published logs are clean.** They were captured at 02:54 on 2026-08-10, *before*
the 3 synthetic `tx timeout` lines were injected into `/dev/kmsg` at ~03:07 to test the
watchdog. The 22 `tx timeout` lines they contain are all genuine hardware events —
**21 HCI command timeouts plus 1 `link tx timeout`** (ACL supervision, a different
layer; the two must not be pooled — `EX-015`).

⚠️ If you re-collect logs from the live system with `journalctl -k -b 0`, that output
*will* include the 3 synthetic lines. Strip them, or note them explicitly.

All identifying data (MAC addresses, the Wi-Fi AP BSSID, filesystem UUIDs) has been
replaced with deterministic placeholders by `tools/sanitize-logs.sh`. Run that on any
further logs before attaching them.
