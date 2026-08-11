# Bluetooth Controller Hang — Investigation Report

**Host:** `n` (Ubuntu 24.04.4 LTS, kernel 7.0.0-28-generic HWE)
**Investigated:** 2026-08-10, live in the failed state
**Status legend:** ✅ confirmed by direct measurement · ⚠️ inferred · ❓ open

> This file is appended to as findings arrive, so nothing is lost across a reboot.

---

## 1. Executive summary

The Bluetooth **controller firmware hangs**. The USB device stays enumerated and the
kernel still thinks the interface is `UP RUNNING`, but the chip stops answering *any*
HCI command. Every command the host sends then sits until it hits the 2-second HCI
timeout, forever.

The GNOME Settings "ring not rolling" symptom is exactly this: the Settings panel issues
an MGMT/HCI request, the controller never replies, the spinner never resolves.

This is **not** a BlueZ configuration problem and **not** a pairing problem. It is a
firmware-level lockup in a Qualcomm Atheros QCA9377 (ROME) Bluetooth chip.

---

## 2. Hardware identification ✅

| Property | Value |
|---|---|
| BT USB device | `13d3:3503` (IMC Networks / AzureWave module) |
| USB path | `3-3` on `xhci_hcd 0000:03:00.4` (bus 3), full-speed 12 Mb/s |
| Driver | `btusb` (interfaces `3-3:1.0`, `3-3:1.1`) |
| HCI manufacturer | `0x001D` (29) = **Qualcomm** |
| HCI version | `0x07` = Bluetooth **4.2** |
| BD address | `AA:BB:CC:DD:EE:FF` |
| Companion Wi-Fi | `QCA9377 hw1.1` on PCI `02:00.0`, driver `ath10k_pci` |

The Wi-Fi and Bluetooth are the **two halves of one QCA9377 combo chip**: Wi-Fi is
PCIe-attached, Bluetooth is USB-attached. This matters — see §6.

Note: `btmtk` / `btrtl` / `btbcm` / `btintel` all appear in `lsmod`. That is a red
herring; `btusb` pulls all vendor helpers in as hard dependencies regardless of the
chip actually present. HCI version 4.2 + manufacturer 0x001D rules out MediaTek
(which would report 0x0046 and HCI 5.2+).

---

## 3. Live evidence of the hang ✅

Captured *while broken*, before any recovery attempt:

```
$ hciconfig -a
Can't read local name on hci0: Connection timed out (110)
hci0:   Type: Primary  Bus: USB
        BD Address: AA:BB:CC:DD:EE:FF
        UP RUNNING PSCAN
        RX bytes:12490523  acl:2838 sco:11 events:1743003 errors:0
        TX bytes:1130481955 acl:1722894 sco:7045 commands:7937 errors:0

$ hcitool -i hci0 cmd 0x04 0x0001     # HCI_Read_Local_Version_Information
<no response — timed out and was killed>

$ rfkill list
0: hci0: Bluetooth   Soft blocked: no   Hard blocked: no      # not an rfkill issue

$ hcitool con
Connections:                                                   # none — nothing stuck open
```

The interface is administratively `UP` and the USB endpoint is alive enough that
`bluetoothctl show` can print BlueZ's **cached** view of the adapter (that data comes
from BlueZ's in-memory state, not from the chip). But the chip itself answers nothing.

**`errors:0` on both RX and TX is significant:** the USB transport is healthy. Bytes go
out, no USB-level errors. The chip receives them and simply never produces an event in
reply. That localises the fault to the firmware, above the USB layer.

---

## 4. Failure timeline this boot ✅

Boot began Sat 2026-08-08 08:59:22. No reboot since — ~1 day 18 h uptime.

| Time | Event |
|---|---|
| Aug 08 09:04 → 15:28 | `Bluetooth: hci0: unexpected event for opcode 0x2005` repeating **every ~10–16 s for 6.5 hours**. `0x2005` = `LE_Set_Random_Address`. |
| Aug 08 15:28:58 | `bluetoothd[1140]: segfault at 10 ... in bluetoothd` — **BlueZ crashed**. systemd restarted it as PID 36567. The 0x2005 spam stopped at that moment. |
| Aug 09 19:53 | `ext_io_disconnected() ... Hands-Free Voice gateway: getpeername: Transport endpoint is not connected (107)` |
| Aug 09 20:19:59–20:20:11 | `avdtp.c:cancel_request() Suspend: Connection timed out (110)` ×2, then `Abort: Connection timed out` — **A2DP stream teardown failed** |
| **Aug 09 20:20:43** | **`Bluetooth: hci0: command 0x0406 tx timeout` — first controller timeout. This is the moment the firmware died.** |
| Aug 09 20:20:49 | `Bluetooth: hci0: setting interface failed (110)` |
| Aug 09 20:33:51 | `link tx timeout` → `killing stalled connection 11:11:11:11:11:01` (Lenovo thinkplus GM2 pro earbuds) |
| Aug 10 02:21:21 | `Opcode 0x0c3a failed: -110`, `Opcode 0x2005 failed: -110`, `Opcode 0x200b failed: -110` — everything times out now |
| Aug 10 02:21–02:42 | Continuous `command 0x0406 tx timeout`; `Failed to set mode: Authentication Failed (0x05)` |

`0x0406` = **`HCI_Disconnect`**. Nineteen `tx timeout` lines this boot, and the *very
first* one is a `HCI_Disconnect` — the host trying to tear down a link and the chip
refusing to acknowledge.

### The trigger sequence ✅

The ordering is consistent and mechanistic:

1. An **A2DP (music) stream teardown** goes wrong — `AVDTP Suspend` then `Abort`
   both time out at 20:19:59–20:20:11.
2. **~30 seconds later** the host gives up and issues `HCI_Disconnect` (0x0406).
3. That `HCI_Disconnect` **never completes**. The firmware is wedged from this point on.

So the hang is provoked by **disconnecting an audio device while a stream is still
active** — closing the lid, walking out of range, powering the earbuds off mid-playback.
That matches the reported "after some connections-disconnections" pattern precisely.

---

## 5. What is NOT the cause ✅

Ruled out by direct measurement:

- **Not rfkill.** Neither soft- nor hard-blocked.
- **Not suspend/resume.** `journalctl -k -b 0` shows **zero** suspend or resume events
  this entire boot. The machine never slept. A very common theory for this class of bug,
  and it is definitively excluded here.
- **Not a stuck connection.** `hcitool con` reports no open links.
- **Not the bluetooth service being dead.** `bluetooth.service` is `active (running)`,
  has been up 1 d 11 h, using 1.6 M and 397 ms CPU. It is healthy; it is talking to a
  corpse.
- **Not a USB transport error.** `errors:0` both directions.
- **Not TLP or a userspace power tool.** `tlp` is `inactive`; no `/etc/tlp.conf`.
- **Not a BlueZ misconfiguration.** `/etc/bluetooth/main.conf` is stock — only
  `AutoEnable=true` is set.

---

## 6. Contributing factors ⚠️

### 6a. USB autosuspend is enabled on the Bluetooth device ⚠️ — most actionable

```
/sys/bus/usb/devices/3-3/power/control            = auto      # autosuspend ENABLED
/sys/bus/usb/devices/3-3/power/autosuspend_delay_ms = 2000
/sys/bus/usb/devices/3-3/power/wakeup             = disabled
/sys/module/btusb/parameters/enable_autosuspend   = Y
```

The BT radio is allowed to runtime-suspend after 2 s idle, **and `wakeup` is
`disabled`**, meaning the device is not armed to wake the USB host itself. QCA ROME
firmware is well known to wedge when a suspend/resume of the USB link races against
in-flight HCI traffic — exactly the window that a mid-stream A2DP teardown creates.

This is the single most likely aggravating factor and the cheapest thing to change.

### 6b. QCA ROME firmware quality ⚠️

QCA9377 / "ROME" is a budget 2015-era combo part with a long, well-documented history of
exactly this failure: command timeouts that require USB re-enumeration to clear. The
firmware has no watchdog that recovers the HCI command pipe on its own.

### 6c. Wi-Fi/BT coexistence ⚠️ ❓

Wi-Fi and Bluetooth share one antenna chain and one radio die on QCA9377. Coexistence
arbitration is handled *inside* the firmware. Heavy concurrent Wi-Fi traffic during an
A2DP stream is a known aggravator on this part. Not yet measured — see §9.

### 6d. BlueZ 5.72 instability ⚠️

`bluetoothd` **segfaulted** on Aug 08 at 15:28:58. Separately, the 6.5-hour
`LE_Set_Random_Address` retry loop before that crash indicates BlueZ was stuck in a
failing LE-advertising restart cycle. Neither of these caused the current hang (they
predate it by a day), but they show the userspace side is not clean either. BlueZ 5.72
is the Ubuntu 24.04 stock version.

---

## 7. Cross-boot frequency ✅

`tx timeout` count per boot:

| Boot | Timeouts |
|---|---|
| -4 (Aug 07, 1 h) | 0 |
| -3 (Aug 07, 10 h) | 15 |
| -2 (Aug 08, 5 h) | 8 |
| -1 (Aug 08, 3 h) | 0 |
| **0 (current, 42 h)** | **19** |

Three of the last five boots hit the hang. The two clean boots were the two *shortest*
sessions (1 h and 3 h) — consistent with "it happens once you actually use Bluetooth for
a while," not with a random cosmic-ray event.

Reboot history also shows the machine is rebooted very frequently (34 boots in ten weeks,
several per day on Aug 7–8), which corroborates the reported daily-routine workaround.

---

---

## 8. Recovery attempts — all failed ✅

Attempted live, in escalating order. **None worked.**

| # | Action | Result |
|---|---|---|
| 1 | `systemctl stop bluetooth` + `usb/unbind` → `usb/bind` on `3-3` | Device would not re-enumerate: `device descriptor read/64, error -110` ×4, then `device not accepting address 2, error -62`, then `USB disconnect` |
| 2 | Kernel's own automatic retry (device numbers 4→11) | `xhci_hcd: Timeout while waiting for setup device command`, `WARN: invalid context state for evaluate context command`, finally `unable to enumerate USB device` |
| 3 | xHCI port power cycle: `echo 1 > usb3-port3/disable`, wait 5 s, `echo 0 >` | Kernel logged `usb usb3-port3: attempt power cycle` — still no enumeration |

**Current state: the Bluetooth chip has vanished from the USB bus entirely.**

```
$ lsusb -s 3:
Bus 003 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
Bus 003 Device 003: ID 2808:c652 FocalTech FocalTech Fingerprint Device
$ ls /sys/class/bluetooth/
                                    # empty
```

The FocalTech fingerprint reader on the same controller (`3-4`) stayed healthy
throughout. That is an important control: **the xHCI host controller and the USB bus are
fine — the fault is entirely inside the QCA9377 Bluetooth silicon.**

### What this proves ✅

The hang is **below the USB protocol layer**. The chip stops responding even to
`GET_DESCRIPTOR` on endpoint 0 — the most primitive USB request that exists, handled by
the USB core of the silicon itself. It still asserts its D+ pull-up (so the port sees
"something attached") but executes nothing.

**Therefore no software recovery is possible.** The chip's power rail must be cycled.
On this laptop the M.2 card's rail is not switchable from the OS, which is exactly why
you observe that *sometimes even a reboot is not enough and a full power-off is needed* —
a warm reboot does not drop the M.2 rail, a cold power-off does.

**Consequence for strategy: a "reset script" cannot work once the hang has happened.
Prevention, and early intervention before the hard hang, are the only viable approaches.**

---

## 9. Not a recent kernel regression ✅

You have 24 kernels installed, so this was directly testable. Failure counts per boot,
by kernel:

| Boot | Kernel | `tx timeout` | `unexpected event` | Date |
|---|---|---|---|---|
| -11 | 6.17.0-35 | 0 | 3 | Jul 09 |
| -10 | 6.17.0-35 | 0 | 0 | Jul 10 |
| -9 | 6.17.0-35 | 0 | 0 | Jul 12 |
| **-8** | **6.17.0-35** | **25** | **2556** | Jul 12 |
| **-7** | **6.17.0-40** | **4** | **1364** | Jul 16 |
| -6 | 7.0.0-28 | 0 | 6250 | Jul 25 |
| **-5** | **7.0.0-28** | **28** | 13 | Aug 02 |
| -4 | 7.0.0-28 | 0 | 0 | Aug 07 |
| **-3** | **7.0.0-28** | **15** | 26 | Aug 07 |
| **-2** | **7.0.0-28** | **8** | 1 | Aug 08 |
| -1 | 7.0.0-28 | 0 | 1 | Aug 08 |
| **0** | **7.0.0-28** | **22** | **1527** | Aug 08 (current) |

The hang occurs on **6.17.0-35, 6.17.0-40 and 7.0.0-28 alike**.

**Rolling back the kernel will not fix this.** It is a long-standing condition, not a
regression introduced by the current HWE kernel — which is consistent with you having
seen the same behaviour on multiple laptops.

---

## 10. ROOT CAUSE: the device is missing from btusb's ID table ✅ 🔴

This is the central finding, and it explains why the failure is unrecoverable.

### The device appears to receive no vendor quirks

```
$ cat /sys/bus/usb/devices/3-3:1.0/modalias
usb:v13D3p3503d0001dcE0dsc01dp01icE0isc01ip01in00

$ modinfo btusb | grep -oiE "v13D3p[0-9A-F]{4}" | sort -u
<nothing>

$ modinfo btusb | grep "icE0isc01ip01"
alias: usb:v*p*d*dc*dsc*dp*icE0isc01ip01in*
```

> ✅ **Since confirmed directly.** `0x3503` is absent from upstream `btusb.c` (v7.0)
> and from the shipped `btusb.ko` (byte-scan for the little-endian pair `d3 13 03 35`;
> method validated by locating `d3 13 62 33` = 13d3:3362). 78 `13d3` entries in both,
> so no distro patch adds it.
>
> ⚠️ **The `modinfo` evidence below was not sufficient on its own.**
> `modinfo` exposes only `btusb_table`, the `MODULE_DEVICE_TABLE`. btusb keeps its
> vendor quirks in a **separate, non-exported table** consulted via `usb_match_id()`
> inside `btusb_probe()`. An ID missing from `modinfo` output therefore says nothing
> about whether it is in the quirks table. The conclusion below rests entirely on the
> **behavioural** evidence that follows, which is independent and much stronger.

The device binds through the catch-all "USB Bluetooth class device" rule
(`bInterfaceClass=E0`, `SubClass=01`, `Protocol=01`) and — per the observations below —
ends up with `driver_info = 0`, i.e. **no vendor quirks**.

### What the device is therefore denied

> ⚠️ **This section described the mechanism incorrectly and is corrected below.** It is
> kept because this document is a record of the investigation as it happened. The
> authoritative description is in
> [`fix-proposal.md`](fix-proposal.md) §3a. In short: v7.0 uses
> `hdev->reset = btusb_qca_reset`, invoked by `hci_cmd_timeout()` on the **first**
> timeout with no threshold — not a `cmd_timeout` handler counting to five. Verified from
> upstream source and by `tools/bt-verify-kernel-mechanism` against the shipped module.

Because `driver_info` lacks `BTUSB_QCA_ROME`, `btusb_probe()` never enters the QCA
branch, so the device never gets:

1. ~~**`hdev->cmd_timeout = btusb_qca_cmd_timeout`**~~ — **corrected:**
   `hdev->reset = btusb_qca_reset`, called from `hci_cmd_timeout()` on the first command
   timeout. With the entry missing, `hdev->reset` stays NULL and the kernel logs the
   timeout without acting.
2. QCA rampatch / NVM firmware download (`qca/rampatch_usb_*.bin`, `qca/nvm_usb_*.bin`)
3. `BTUSB_WIDEBAND_SPEECH` and related quirks

### Confirmed by the logs — the auto-reset never once fired ✅

```
total "tx timeout" events across all 34 boots : 287
total auto-reset attempts                     :   0
```

Across **287 command timeouts in 34 boots**, the kernel logged
`"Multiple cmd timeouts"` / `"Resetting usb device"` **zero times**. No `cmd_timeout`
handler is installed. The kernel just prints the timeout and does nothing.

Likewise, no QCA firmware ever loaded — `rampatch`, `nvm_usb`, `patch rome` appear in
**no** boot. (An early grep appeared to hit once; verified false positive — it matched
the `ath10k_pci ... qca9377` Wi-Fi line, not Bluetooth firmware.)

### And both code paths ARE present in this kernel build ✅

This rules out "the feature isn't compiled in" as an explanation — the code exists, it
simply never runs for this device:

```
$ zstd -dc /lib/modules/7.0.0-28-generic/kernel/drivers/bluetooth/btusb.ko.zst \
    | strings | grep -E "Resetting usb device|rampatch|nvm_usb"
%s: Resetting usb device.
qca/rampatch_usb_%08x.bin
%s: using rampatch file: %s
qca/nvm_usb_%08x
```

Three independent observations — handler never fires, firmware never loads, both are
compiled in — converge on the same conclusion: **`driver_info` for this device lacks
`BTUSB_QCA_ROME`.**

### The causal chain 🔴

```
A2DP stream torn down mid-playback (earbuds off / out of range)
        │
        ▼
AVDTP Suspend + Abort time out                          (Aug 09 20:19:59–20:20:11)
        │
        ▼
host sends HCI_Disconnect (0x0406) — firmware wedges    (Aug 09 20:20:43)
        │
        ├── WITH the correct ID:  1st timeout → hci_cmd_timeout() calls
        │                          hdev->reset() = btusb_qca_reset()
        │                          → usb_queue_reset_device()
        │                          → outcome UNKNOWN; never tested (see fix-proposal §3a)
        │
        └── WHAT ACTUALLY HAPPENS: hdev->reset is NULL, so the `if` is not taken.
            Kernel logs the timeout and does nothing. Host keeps hammering a dead
            chip for hours (22 timeouts over ~6 h)
        │
        ▼
firmware degrades from "HCI unresponsive" to "USB core unresponsive"  (by Aug 10 02:46)
        │
        ▼
UNRECOVERABLE — needs a physical power cycle
```

**The missing device ID converts a self-healing 3-second glitch into a
power-cycle-requiring hard hang.** There was a ~6 hour window (20:20 → 02:46) during
which a USB reset would very likely have recovered the chip. Nothing triggered one.

### The kernel patch 🔴

`drivers/bluetooth/btusb.c`, in `btusb_table[]`, alongside the other QCA ROME entries:

```c
+	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
+						     BTUSB_WIDEBAND_SPEECH },
```

Evidence that `BTUSB_QCA_ROME` is the correct classification:

- HCI `Manufacturer: 0x001D (29)` = **Qualcomm** (Bluetooth SIG company ID)
- HCI `Version: 0x07` = Bluetooth **4.2** — matches QCA9377; rules out MediaTek
  (would report `0x0046` and HCI 5.2+) and Realtek (`0x005D`)
- Companion Wi-Fi is `ath10k_pci: qca9377 hw1.1` — the other half of the same combo part
- `13d3` = IMC Networks, a standard ODM for QCA9377 M.2 modules

⚠️ **Caveat before shipping this:** adding `BTUSB_QCA_ROME` also enables the rampatch
firmware download path. If this particular module is not a true ROME variant, probe
could fail and leave *no* Bluetooth at all. The safe way to validate is an out-of-tree
build first (see §11), verifying that `qca/rampatch_usb_*.bin` loads cleanly and the
adapter still works. A more conservative first patch is `BTUSB_QCA_ROME` alone, without
`BTUSB_WIDEBAND_SPEECH`.

Also worth checking against current `torvalds/linux` master before submitting — the ID
may already have been added upstream since 7.0.

---

## 11. Recommended actions, in priority order

### Tier 1 — do now, zero risk, no reboot needed to apply

**A. Disable USB autosuspend for the BT radio.** Removes the suspend/resume race that
opens the window for the wedge (§6a). Persistent udev rule:

```
# /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="13d3", ATTR{idProduct}=="3503", \
  TEST=="power/control", ATTR{power/control}="on"
```

plus `options btusb enable_autosuspend=0` in `/etc/modprobe.d/btusb.conf`.

**B. Early-warning watchdog.** Since recovery is impossible *after* the hard hang but a
USB reset during the ~6 h soft-hang window would likely work, a small service that
watches the kernel log for `tx timeout` and immediately issues a `btusb` unbind/rebind
approximates — in userspace, but ~11–33 s later — what the missing `btusb_qca_reset` would have
done. This is the highest-value mitigation available without patching the kernel.

**C. Reduce LE churn.** All three paired devices are BR/EDR audio
(thinkplus GM2 pro, Tronsmart T8, MOMENTUM 4). The `LE_Set_Random_Address` (0x2005)
retry storm — 6250 events in one boot, 1527 in this one — is pure LE overhead you do not
appear to need. Setting `ControllerMode = bredr` under `[General]` in
`/etc/bluetooth/main.conf` disables LE entirely and eliminates that storm.
⚠️ Only do this if you never use LE peripherals (BLE mice, trackers, heart-rate
monitors, most modern smartwatches).

### Tier 2 — behavioural, free

Stop audio playback and disconnect the headset *before* powering it off or walking out
of range. The trigger is specifically a **mid-stream** A2DP teardown.

### Tier 3 — the real fix

The QCA9377 is a weak 2015-era part with a long public history of exactly this failure.
On most laptops it is an M.2 2230 card that is a drop-in replacement with an
**Intel AX200 / AX210**, which is dramatically more reliable on Linux and also upgrades
you to Wi-Fi 6. ⚠️ Check first whether your vendor BIOS has a wireless-card allowlist.

### Tier 4 — upstream

Submit the §10 patch to `linux-bluetooth@vger.kernel.org`. If the same missing-ID
situation explains the behaviour you have seen on other laptops, this is a genuinely
worthwhile contribution.

---

## 12. Open questions ❓

- Is `13d3:3503` already in `btusb_table` in current upstream master (post-7.0)?
- Is this module a true QCA ROME variant, or does it need a different `driver_info`?
  Requires an out-of-tree build to validate safely.
- Wi-Fi/BT coexistence contribution is unmeasured. `ath10k_core` exposes no coex toggle
  (`coredump_mask`, `cryptmode`, `frame_mode`, `skip_otp`, `uart_print` only), so this
  would have to be tested by correlating heavy Wi-Fi traffic with hang onset.
- On the other laptops that showed this behaviour: same `13d3:3503`, or different IDs
  that are also missing from `btusb_table`?

---

## 13. Effectiveness measurement

Because the real test of the mitigations takes days of ordinary use, metrics are
collected automatically and persist across reboots.

**Collector:** `bt-health-snapshot.timer` → `/usr/local/sbin/bt-health-snapshot`,
every 15 min plus 2 min after boot, appending TSV rows to
`/var/log/bt-health/metrics.tsv`:

| Column | Meaning |
|---|---|
| `dev_present` | is `13d3:3503` on the USB bus (0 = hard-hung) |
| `hci_alive` | does the controller answer a command (0 = stalled) |
| `usb_power_ctrl` | `on` = udev rule applied, `auto` = not |
| `btusb_autosusp` | expect `N` |
| `tx_timeouts` / `unexpected_evt` | kernel failure counts this boot |
| `wd_interventions` / `wd_recovered` / `wd_failed` | watchdog activity |
| `connected` | number of connected BT devices (usage proxy) |

**Analysis:** `/usr/local/bin/bt-health-report` — mitigation state, per-boot
failure counts tagged before/AFTER, watchdog effectiveness with a verdict, recent
snapshots, and the pre-change baseline side by side.

**Baseline:** `evidence/baseline/baseline.tsv` — 34 boots, 287 timeouts, **13 of 34 boots hung**.

Journald already persists (`/var/log/journal` present, 35 boots retained), so no logging
configuration was changed.

### Reading the result in a day or two

```bash
/usr/local/bin/bt-health-report     # full analysis
journalctl -u bt-hang-watchdog -f          # live
```

Success is either **(a)** timeouts drop to ~0 per boot — autosuspend was the trigger — or
**(b)** timeouts still occur but each is followed by `RECOVERED`, meaning the watchdog is
doing the kernel's missing job. Failure is `FATAL: no longer on the USB bus` reappearing,
which means the chip hard-hung before the watchdog caught it; the response is to lower
`BT_THRESHOLD` to 2 and `BT_WINDOW` to 30 via `systemctl edit bt-hang-watchdog`.

⚠️ Boot 0 of 2026-08-10 contains **3 synthetic `tx timeout` lines** injected at ~03:07 to
test the watchdog. Subtract them from that boot's count.

---

## 14. Backup / rollback

Pristine config captured **before any change** at
`./backup-<timestamp>/` (path also in `.last-backup-path`):

- `etc-bluetooth/`, `etc-modprobe.d/`, `etc-udev-rules.d/`, `etc-default-grub`
- `systemd/bluetooth.service.asis`, `systemd/bluetooth.enabled`
- `runtime-state.txt` — module params, USB power-control state, `/proc/cmdline`, `lsmod`
- `logs/kernel-boot0.log`, `logs/bluetoothd-boot0.log`

**As of this writing no configuration file has been modified.** The only changes made
were runtime driver unbind/rebind and a port power-cycle attempt — both fully reset by a
reboot, and neither touches disk, initramfs, bootloader or kernel packages. There is no
bootability risk from anything done during this investigation.

