# qca9377-bt-hang

**Your Bluetooth dies after a while and only a full power-off brings it back.**
This repo explains exactly why, and ships a workaround that fixes it without a
kernel patch.

Affects Qualcomm Atheros **QCA9377** (ROME) Bluetooth, USB ID `13d3:3503`, on Linux.

---

## Do you have this bug?

You probably do if **all** of these are true:

```bash
# 1. Bluetooth settings spins forever and never lists devices
# 2. The controller is "up" but answers nothing:
$ hciconfig -a
Can't read local name on hci0: Connection timed out (110)
hci0:   UP RUNNING PSCAN
        RX bytes:12490523 acl:2838 sco:11 events:1743003 errors:0    # <- errors:0

# 3. The kernel log is full of:
$ dmesg | grep "tx timeout"
Bluetooth: hci0: command 0x0406 tx timeout

# 4. And this NEVER appears, no matter how many timeouts you get:
$ dmesg | grep -i "Resetting usb device"
<nothing>
```

Point 4 is the bug. Point 2's `errors:0` means USB is perfectly healthy — the chip
just stopped answering.

Confirm the hardware:

```bash
$ lsusb | grep 13d3
Bus 003 Device 002: ID 13d3:3503 IMC Networks
$ bluetoothctl show | grep -E "Manufacturer|Version"
	Manufacturer: 0x001d (29)      # Qualcomm
	Version: 0x07 (7)              # Bluetooth 4.2
```

---

## What's actually wrong

`13d3:3503` appears not to be matched by btusb's vendor quirks table. It binds through
the generic USB-Bluetooth-class rule with `driver_info = 0`, so it never receives
`hdev->cmd_timeout = btusb_qca_cmd_timeout` — the handler that USB-resets a controller
after 5 consecutive HCI command timeouts.

Measured on the affected machine:

```
"tx timeout" events across 12 boots : 102
automatic reset attempts            :   0
```

Both the reset handler and the QCA firmware path *are* compiled into the running
`btusb.ko` (verified with `strings`). They simply never run for this device.

### Why that turns a glitch into a power-cycle

The controller fails in two stages:

| Stage | State | Recoverable? |
|---|---|---|
| 1 — soft | HCI unresponsive, USB fine | **yes** — a USB reset clears it |
| 2 — hard | USB core unresponsive, device drops off the bus | **no** — cold power-off only |

With the quirk, a reset fires within seconds of stage 1 and you notice nothing but an
audio dropout. Without it, the host hammers a stalled controller for hours until it
decays into stage 2.

On the logged instance, **stage 1 lasted ~6 hours** before decaying. That entire window
was a free recovery nobody took.

Once in stage 2, none of this works — all verified, all failed:

```
usb 3-3: device descriptor read/64, error -110      # driver unbind/rebind
usb 3-3: device not accepting address 2, error -62
usb usb3-port3: attempt power cycle                 # xHCI port power cycle
usb usb3-port3: unable to enumerate USB device
```

**A warm reboot is often not enough** — it doesn't drop the M.2 power rail. That is why
you sometimes need a full shutdown.

### The trigger

Tearing down an **A2DP stream mid-playback** — powering headphones off or walking out of
range while music is playing.

```
20:19:59  avdtp.c: Suspend: Connection timed out (110)
20:20:11  avdtp.c: Abort:   Connection timed out (110)
20:20:43  Bluetooth: hci0: command 0x0406 tx timeout   <-- wedged (0x0406 = HCI_Disconnect)
```

---

## Install

```bash
git clone https://github.com/<you>/qca9377-bt-hang
cd qca9377-bt-hang
sudo ./install.sh            # dry run — shows exactly what it would do
sudo ./install.sh --apply
```

Uninstall is complete — every installed file is new, nothing pre-existing is touched:

```bash
sudo ./uninstall.sh                          # dry run
sudo ./uninstall.sh --apply
sudo ./uninstall.sh --apply --purge-metrics  # also delete collected metrics
./tools/verify-restored.sh                   # confirm nothing is left behind
```

[`docs/restore-original-state.md`](docs/restore-original-state.md) documents the full
path back to the pre-install state, including the few things `uninstall.sh` deliberately
does not touch (collected metrics, and settings changed outside this repo).

### What it installs

**1. A watchdog** (`bt-hang-watchdog.service`) — reimplements the missing kernel handler
in userspace. It tails the kernel log and, after 3 controller timeouts in 60 s, issues
`USBDEVFS_RESET` (the same ioctl `usb_queue_reset_device()` performs), escalating to USB
unbind/bind if needed. Threshold is 3 rather than the kernel's 5, deliberately: there is
no downside to resetting an already-broken radio, and reacting during stage 1 is the
whole point.

**2. USB autosuspend disabled** for the radio — `btusb enable_autosuspend=0` plus a udev
rule pinning `power/control=on`. Runtime suspend racing with in-flight HCI traffic widens
the window in which the stall happens.

**3. A metrics collector** (optional, `--no-metrics` to skip) — snapshots health every
15 min to `/var/log/bt-health/metrics.tsv`, surviving reboots.

Confirming a recovery worked needs `hciconfig` or `btmgmt` (package `bluez`). Without
either, the watchdog still resets the controller but logs the attempt as unverified
rather than counting it as a failure — so a missing tool cannot make it disable itself.

### Different controller?

The watchdog is not chip-specific:

```bash
BT_VID=0cf3 BT_PID=e300 sudo -E ./install.sh --apply
```

---

## Is it working?

```bash
bt-health-report            # full analysis
journalctl -u bt-hang-watchdog -f    # live
```

Success is either of:

- **tx-timeout counts drop to ~0 per boot** — autosuspend was the trigger
- **timeouts still happen, but each is followed by `RECOVERED`** — the watchdog is doing
  the kernel's job

Failure is `FATAL: no longer on the USB bus` reappearing: the chip reached stage 2 before
the watchdog caught it. Lower the threshold and re-measure:

```bash
sudo systemctl edit bt-hang-watchdog     # BT_THRESHOLD=2, BT_WINDOW=30
```

Baseline for comparison (`data/baseline.tsv`): **102 timeouts across 12 boots, 6 of 12
boots hung.**

### Tunables

| Variable | Default | Meaning |
|---|---|---|
| `BT_THRESHOLD` | `3` | timeouts inside the window before intervening |
| `BT_WINDOW` | `60` | sliding window, seconds |
| `BT_COOLDOWN` | `180` | minimum seconds between recovery attempts |
| `BT_MAX_FAILS` | `3` | consecutive failures before idling until reboot |

---

## The real fix

A one-line kernel patch — add the device to btusb's QCA ROME quirks:

```c
+	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
+						     BTUSB_WIDEBAND_SPEECH },
```

> ⚠️ **Untested — do not ship this blindly.** `BTUSB_QCA_ROME` also enables the rampatch
> firmware download path. If this module is not a true ROME variant, probe can fail and
> leave you with *no* Bluetooth, which is worse than the current intermittent failure.
> See [`docs/fix-proposal.md`](docs/fix-proposal.md) for the validation plan and
> [`docs/bug-report.md`](docs/bug-report.md) for the full report.

Also unverified: whether the ID is genuinely absent from the quirks table. `modinfo`
cannot answer this — it exposes only `btusb_table`, while the quirks live in a separate
non-exported table matched via `usb_match_id()`. The conclusion here rests on the
behavioural evidence above, and still wants source-level confirmation.

Longer term, the QCA9377 is a weak 2015-era part with a long history of this failure. On
most laptops it is an M.2 2230 card that swaps directly for an Intel AX200/AX210 — far
more reliable on Linux, and Wi-Fi 6 as a bonus. Check for a BIOS wireless allowlist first.

---

## Not a kernel regression

Tested across every kernel available on the affected machine:

| Kernel | Hangs? |
|---|---|
| 6.17.0-35 | yes |
| 6.17.0-40 | yes |
| 7.0.0-28 | yes |

Rolling back the kernel does not help.

---

## Repository layout

```
bin/                  watchdog + metrics collector
systemd/              unit files
etc/                  modprobe + udev configuration
tools/                health report, log sanitiser, restoration verifier
docs/
  investigation.md    full investigation, every measurement
  bug-report.md       ready to file with linux-bluetooth
  fix-proposal.md     the patch, its risks, validation plan
  changes-applied.md  exact system changes + rollback
  restore-original-state.md  full path back to the pre-install state
data/
  baseline.tsv        pre-mitigation failure counts
  logs/               sanitised kernel + bluetoothd logs
```

### Publishing logs

Kernel logs contain your **Wi-Fi access point BSSID**, which public geolocation databases
(WiGLE, Google, Apple) index — it can reveal where the machine physically is. Always run
logs through the sanitiser before attaching them anywhere:

```bash
./tools/sanitize-logs.sh /path/to/kernel.log
```

It replaces MACs and BSSIDs (**colon or dash separated**), UUIDs and IPv4 addresses with
deterministic placeholders, then verifies none survived — checking every form it
substitutes, so a missed form cannot produce a false all-clear. It is safe to run in
place (`sanitize-logs.sh kernel.log kernel.log`): output is built in a temp file and
renamed only after verification passes. The logs in `data/logs/` were produced this way.

---

## Status

| | |
|---|---|
| Root cause identified | ✅ behavioural evidence; source-level confirmation pending |
| Watchdog detection | ✅ tested end-to-end via `/dev/kmsg` injection |
| Watchdog recovery path | ⚠️ **untested** — needs a live controller |
| Autosuspend setting | ✅ applied and verified |
| udev rule | ⚠️ untested — fires on next device `add` |
| Kernel patch | ❌ written, not built or tested |

The recovery path and udev rule could not be exercised because the controller was already
in stage 2 when the work was done. They need a cold power-off to validate.

## Contributing

Useful data points, especially:

- Other USB IDs showing the same signature (timeouts with zero reset attempts)
- Whether `13d3:3503` is present in the quirks table in current mainline
- Confirmation that the patch works, if you build it

## License

GPL-2.0. See [LICENSE](LICENSE).
