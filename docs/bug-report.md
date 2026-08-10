# Bug report — btusb: QCA9377 (13d3:3503) gets no `cmd_timeout` handler, degrading a recoverable firmware stall into a hard hang

**Subsystem:** `drivers/bluetooth/btusb.c`
**Reporter contact:** yaroslav.voytovych@gmail.com
**Date:** 2026-08-10
**Suggested recipients:** `linux-bluetooth@vger.kernel.org`, `linux-kernel@vger.kernel.org`
**Maintainers:** Marcel Holtmann, Luiz Augusto von Dentz
**Regression:** No — reproduced on 6.17.0-29, 6.17.0-35, 6.17.0-40 and 7.0.0-28, over 10 weeks

---

## Summary

USB Bluetooth device `13d3:3503` (Qualcomm Atheros QCA9377 / ROME, IMC Networks module)
appears not to be matched by btusb's vendor quirks table. It therefore probes with
`driver_info = 0` and never receives
`hdev->cmd_timeout = btusb_qca_cmd_timeout`.

When the controller firmware stalls, nothing resets it. The kernel logs command timeouts
indefinitely while the chip decays from a *recoverable* state (HCI unresponsive, USB
healthy) into an *unrecoverable* one (USB core unresponsive, device drops off the bus).
The latter cannot be cleared by any software means — not by driver rebind, not by USB
port power-cycle, and not by a warm reboot, because that does not drop the M.2 power
rail. A full power-off is required.

**The missing quirk turns a stall the kernel is already designed to recover from into a
hardware-power-cycle event, several times a week.**

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

## Reproducer

1. Pair a classic (BR/EDR) A2DP audio device — reproduced with Sennheiser MOMENTUM 4,
   Lenovo thinkplus GM2 pro, Tronsmart T8.
2. Start audio playback.
3. **While the stream is active**, power the device off or walk out of range — i.e. force
   an ungraceful teardown rather than a clean disconnect.
4. AVDTP `Suspend` and `Abort` time out; ~30 s later the host issues `HCI_Disconnect`.
5. That command never completes. The controller is stalled from this point on.

Not reliably reproducible on demand — it depends on the timing of the teardown — but it
occurred in **13 of 34 consecutive boots** under ordinary daily use.

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

### Why this matters more than a missed optimisation

Without the handler there is no back-pressure of any kind. The host continues submitting
commands to a stalled controller for hours (22 timeouts over ~6 h in the logged instance).
Whatever internal state causes the stall is never cleared, and the firmware degrades
until the USB core itself stops responding — past the point where any software remedy
exists.

With the handler, a USB reset would have been queued within seconds of the first stall,
during the window when the device still answered USB perfectly. The user-visible bug
would have been a brief audio dropout instead of a forced shutdown.

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
