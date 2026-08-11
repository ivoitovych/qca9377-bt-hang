# Bug report — btusb/QCA9377: `hdev->cmd_timeout` fires too late to recover a stalled controller

**Subsystem:** `drivers/bluetooth/btusb.c`
**Reporter contact:** yaroslav.voytovych@gmail.com
**Date:** 2026-08-11
**Suggested recipients:** `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`
**Maintainers:** Marcel Holtmann, Luiz Augusto von Dentz
**Regression:** No — reproduced on 6.17.0-29, 6.17.0-35, 6.17.0-40 and 7.0.0-28, over 10 weeks

---

## Summary

Two findings, one of which may be the more useful.

**1. A QCA9377 (`13d3:3503`) receives no vendor quirks at all.** It is matched by no
entry in btusb's quirks table, so it probes with `driver_info = 0`, gets no
`hdev->cmd_timeout = btusb_qca_cmd_timeout` and no firmware download. Measured across
**34 boots and four kernel versions: 287 HCI command timeouts, zero reset attempts,
zero firmware loads.** 13 of those 34 boots hung.

**2. Installing that handler would probably not have helped, because `cmd_timeout`
fires too late.** This was tested directly, in both directions:

| Reset issued | Result |
|---|---|
| **+33 s** after the first HCI timeout | ❌ **failed**; controller left the bus |
| **+20 s** after the first HCI timeout — 33 s *before* any USB-level failure | ❌ **failed**; controller left the bus |
| **+11 s** after the first HCI timeout — about as fast as a log-driven watchdog can react | ❌ **failed**; controller left the bus |
| **Before any HCI timeout**, on a bluetoothd audio-teardown failure | ✅ **recovered**; no `tx timeout` occurred at all |

Same hardware, same operation (`USBDEVFS_RESET`, i.e. what `usb_queue_reset_device()`
performs). The only variable is *when*.

**Five for five, a reset issued after the first HCI timeout has failed** — at +11 s,
+16 s, +20 s, +20 s and +33 s. The latency varied by a factor of three with no effect on
the outcome, and every one of those resets landed inside the 45–66 s window during which
the device still answered USB. The single success came from a reset issued *before* any
timeout.

**How narrow is the window?** The lead time between the first bluetoothd audio-teardown
signal and the first HCI timeout has been measured at **−52 s**, **−7 s**, and in one
case not at all (the signal arrived +133 s, after the controller had gone). A 7-second
warning bounds how slow any recovery mechanism can afford to be, kernel-side included.

So there appears to be a window in which this controller is still recoverable, it closes
before the first HCI command times out, and **no existing kernel hook fires inside it**.
The signal that opens the window is visible to bluetoothd (AVDTP/SCO teardown failure),
not to the kernel — which may be why no such hook exists.

When the stall is not caught inside that window, the chip decays from HCI-unresponsive
(USB still healthy) to USB-unresponsive and leaves the bus. That state cannot be cleared
by any software means — not driver rebind, not xHCI port power-cycle, not a warm reboot,
because that does not drop the M.2 power rail. A full power-off is required.

> ⚠️ **Confidence.** Finding 1 is verified three ways and is solid. Finding 2 rests on
> two failed late resets (+20 s and +11 s) and one successful early reset. Offered as a
> hypothesis with evidence, not a settled result. Full logs for all three are attached.
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
- stage 1 measured at 45–66 s in every instrumented case

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
never produces an event in reply. This is precisely the situation
`btusb_qca_cmd_timeout()` exists to handle — and it is never called.

### Stage 2 — degradation to hard hang

Roughly six hours later the chip stopped answering USB control transfers as well.
Recovery attempts, in escalating order, all failed:

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

Only a full power-off recovers it. A warm reboot is frequently insufficient, consistent
with the M.2 rail not being dropped on warm reset.

---

## Root cause analysis

`btusb_qca_cmd_timeout()` increments a counter per HCI command timeout and, on the fifth,
forces a USB reset:

```c
	if (++data->cmd_timeout_cnt < 5)
		return;
	...
	bt_dev_err(hdev, "Multiple cmd timeouts seen. Resetting usb device.");
	err = usb_autopm_get_interface(data->intf);
	if (!err)
		usb_queue_reset_device(data->intf);
```

It is installed only when `driver_info` carries `BTUSB_QCA_ROME` (or `BTUSB_QCA_WCN6855`).

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

### What the missing handler does and does not explain

Without it there is no back-pressure of any kind: the host keeps submitting commands to
a stalled controller and nothing ever tries to clear the condition.

**However — a direct test does not support the assumption that the handler would have
recovered the controller.**

On 2026-08-10 a hang was reproduced with instrumentation running. A userspace watchdog
issued `USBDEVFS_RESET` — the same operation `usb_queue_reset_device()` performs — **20 s
after the first HCI timeout**, which was **33 s before** the first USB-level failure.
The reset failed and the device went on to drop off the bus:

```
07:24:45  Bluetooth: hci0: command tx timeout          <- first timeout
07:25:05  watchdog: 3/3 in window -> intervening        (+20 s)
07:25:23  usb 3-3: reset full-speed USB device number 2 (+38 s)
07:25:38  usb 3-3: device descriptor read/64, error -110 (+53 s)
07:26:48  usb 3-3: USB disconnect, device number 2      (+123 s)
```

`btusb_qca_cmd_timeout()` fires after 5 consecutive timeouts and would have acted at
roughly the same moment, doing roughly the same thing.

### The positive control: an earlier reset succeeded

The obvious follow-up was to try the same reset *earlier*. bluetoothd sees the failure
before the kernel does — in the 08-10 hang it logged audio-teardown errors **52 s**
before the first `tx timeout`:

```
07:23:53  bluetoothd: Unable to get Hands-Free Voice gateway SDP record: Host is down
07:24:36  bluetoothd: No matching connection for device
07:24:41  bluetoothd: a2dp.c:a2dp_config() avdtp_close failed
07:24:45  kernel:     Bluetooth: hci0: command tx timeout        <- cmd_timeout's earliest possible trigger
```

The watchdog was changed to reset on those bluetoothd signals instead. On the boot of
2026-08-10 18:56 — 5 h 21 m, 145 audio/profile events, the failure path entered 6 times:

```
EARLY intervention: 2 audio-teardown failure(s) in 90s — resetting BEFORE any HCI timeout.
  EARLY recovery SUCCEEDED
```

**Zero `tx timeout` events occurred that entire boot.** The early reset did not just
recover the controller after a stall; it kept the stall from ever reaching the state
`cmd_timeout` watches for. That hook would never have fired.

### What this suggests

| Claim | Status |
|---|---|
| The device is matched by no vendor quirks entry | ✅ verified in upstream source and shipped binary; 287 timeouts / 0 resets / 34 boots |
| A reset *after* the first HCI timeout recovers it | ❌ tested once — failed |
| A reset *before* the first HCI timeout recovers it | ✅ tested once — succeeded |
| Adding the device ID alone would fix the hang | ❌ not supported |

If this holds up, `hdev->cmd_timeout` is **architecturally too late** for this failure
mode: the recoverable window closes before the condition it triggers on exists. The
opening signal is at the bluetoothd/AVDTP layer, not the HCI layer.

⚠️ **n = 1 in each direction.** The two hangs may not have been equally severe, and the
cooldown suppressed three further early interventions whose necessity is unknown. This
is a hypothesis with supporting evidence, not a proven result.

Two further corrections from the same session, both to assumptions stated earlier in
this report:

- **Stage 1 is short.** It lasted **53 s**, not the ~6 h originally inferred. The
  6-hour figure measured how long an *untouched* controller stayed enumerated while
  idle — not how long it remains recoverable.
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

- Bluetooth becomes unusable until a full power-off; a reboot is often not enough.
- GNOME Settings shows a Bluetooth panel spinning forever (the MGMT request never
  completes), with no error surfaced to the user.
- Occurred in 13 of 34 consecutive boots under normal daily use.
- The reporter observes the same pattern on **multiple different laptops**, suggesting
  either this device ID is widespread or other IDs are similarly unmatched.

---

## Proposed fix

Add `13d3:3503` to btusb's QCA ROME quirks entries. See `docs/fix-proposal.md` for the patch,
its justification and the validation plan.

A broader question for maintainers: given that an unmatched QCA controller degrades to a
**hardware-power-cycle-only** state, would it be worth installing a generic
`cmd_timeout` reset handler for *any* device binding through the generic Bluetooth-class
entry? A USB reset is cheap and safe on an already-unresponsive controller, and would
make the whole class of "missing device ID" bugs self-limiting rather than catastrophic.

---

## Workaround in use

A userspace watchdog reproduces the missing handler: it tails the kernel log, and after
3 controller timeouts within 60 s issues `USBDEVFS_RESET` on the device, escalating to
USB unbind/bind if that is insufficient. Additionally, USB autosuspend is disabled for
the device (`btusb enable_autosuspend=0` plus a udev rule pinning `power/control=on`),
since runtime suspend racing with in-flight HCI traffic appears to widen the window in
which the stall occurs.

Both are documented in `docs/changes-applied.md`. Effectiveness measurement is ongoing.

---

## Attachments to include when filing

- `evidence/baseline/kernel-boot0.sanitized.log` — full kernel log for the failing boot
- `evidence/baseline/bluetoothd-boot0.sanitized.log` — corresponding bluetoothd log
- `docs/investigation.md` — complete investigation with all measurements
- `evidence/baseline/baseline.tsv` — per-boot failure counts across 34 boots

✅ **The published logs are clean.** They were captured at 02:54 on 2026-08-10, *before*
the 3 synthetic `tx timeout` lines were injected into `/dev/kmsg` at ~03:07 to test the
watchdog. The 22 `tx timeout` events they contain are all genuine hardware events.

⚠️ If you re-collect logs from the live system with `journalctl -k -b 0`, that output
*will* include the 3 synthetic lines. Strip them, or note them explicitly.

All identifying data (MAC addresses, the Wi-Fi AP BSSID, filesystem UUIDs) has been
replaced with deterministic placeholders by `tools/sanitize-logs.sh`. Run that on any
further logs before attaching them.
