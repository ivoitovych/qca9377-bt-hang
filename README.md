# qca9377-bt-hang

**Your Bluetooth dies after a while and only a full power-off brings it back.**
This repo explains exactly why, and ships a workaround that fixes it without a
kernel patch.

Affects Qualcomm Atheros **QCA9377** (ROME) Bluetooth, USB ID `13d3:3503`, on Linux.

---

## Do you have this bug?

One command, no installation, nothing written:

```bash
git clone https://github.com/ivoitovych/qca9377-bt-hang
cd qca9377-bt-hang
./tools/bt-diagnose
```

It auto-detects your USB Bluetooth controller (any vendor, not just this one), checks
whether it still answers HCI commands, and scans every retained boot for the signature.
Exit 0 = not affected, 1 = signature present, 2 = cannot determine.

```
Log evidence
  boots examined            : 34
  HCI command timeouts      : 287
  automatic reset attempts  : 0        <-- this is the bug
```

Timeouts with **zero** resets means the kernel logged the failures and did nothing:
`btusb_qca_cmd_timeout()` is only installed for devices matched by btusb's vendor quirks
table, and yours is not in it.

<details>
<summary>Or check by hand</summary>

You probably have it if **all** of these are true:

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

</details>

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
"tx timeout" events across 34 boots : 287
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

Baseline for comparison (`evidence/baseline/baseline.tsv`): **287 timeouts across 34 boots, 13 of 34
boots hung.**

### Tunables

| Variable | Default | Meaning |
|---|---|---|
| `BT_THRESHOLD` | `3` | timeouts inside the window before intervening |
| `BT_WINDOW` | `60` | sliding window, seconds |
| `BT_COOLDOWN` | `180` | minimum seconds between recovery attempts |
| `BT_MAX_FAILS` | `3` | consecutive failures before idling until reboot |
| `BT_VERBOSE` | `0` | log every detected signal and the window state |
| `BT_EARLY` | `0` | also act on audio-teardown failures — see below |
| `BT_EARLY_THRESHOLD` | `2` | early signals before intervening |
| `BT_EARLY_WINDOW` | `90` | early sliding window, seconds |

### `BT_EARLY` — resetting before the HCI timeout

By default the watchdog waits for `tx timeout`, i.e. for the controller to already have
stopped answering. The 2026-08-10 hang suggests that may be too late: a reset issued 20 s
after the first timeout, and 33 s *before* any USB-level failure, did not recover the
chip.

bluetoothd sees trouble first. In that hang it logged audio-teardown failures **52 s**
before the kernel noticed. `BT_EARLY=1` follows bluetoothd as well as the kernel and
intervenes on those instead:

```bash
sudo systemctl edit bt-hang-watchdog     # Environment=BT_EARLY=1
```

Trigger patterns were selected by measured precision over 12 boots (appearances overall
vs. appearances in boots that hung): `cancel_request() Suspend` 2/2, `Abort` 4/4,
`avdtp_connect_cb` 5/5, `SDP record: Host is down` 10/10, `avdtp_close failed` 4/3.
`Device or resource busy` is excluded at 3/9 — too noisy.

⚠️ **Opt-in, and experimental.** A false positive resets a working controller and drops
live connections. Raise `BT_EARLY_THRESHOLD` if it fires during normal use.

---

## The real fix

A one-line kernel patch — add the device to btusb's QCA ROME quirks:

```c
+	{ USB_DEVICE(0x13d3, 0x3503), .driver_info = BTUSB_QCA_ROME |
+						     BTUSB_WIDEBAND_SPEECH },
```

> ⚠️ **Correct, but on current evidence not sufficient — measured, not assumed.**
> `btusb_qca_cmd_timeout()` only fires *after* HCI commands start timing out, and by
> then the controller appears to be past saving. Both directions were tested:
>
> | Reset issued | Result |
> |---|---|
> | 20 s after the first HCI timeout (where `cmd_timeout` acts) | ❌ failed — chip left the bus |
> | before any HCI timeout, on bluetoothd's audio-teardown failure | ✅ **recovered** |
>
> Sessions: [late reset failed](evidence/sessions/20260810-072445-first-real-hang/) ·
> [early reset worked](evidence/sessions/20260811-002052-early-mode-SUCCESS/).
> This is the `BT_EARLY` mode described above. **n = 1 in each direction.**
>
> ⚠️ **Also untested and risky in its own right.** `BTUSB_QCA_ROME` enables the rampatch
> firmware download path; if this module is not a true ROME variant, probe can fail and
> leave you with *no* Bluetooth. See [`docs/fix-proposal.md`](docs/fix-proposal.md).

**What the missing ID does and does not explain.** That the device receives no
`cmd_timeout` handler is verified three ways (below) and is a real defect worth
reporting. What is *not* established is that installing the handler would prevent this
failure — the one direct test of that said otherwise.

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

## Not a kernel regression

Tested across every kernel available on the affected machine:

| Kernel | Hangs? |
|---|---|
| 6.17.0-29 | yes |
| 6.17.0-35 | yes |
| 6.17.0-40 | yes |
| 7.0.0-28 | yes |

Four kernel versions across ten weeks and 34 boots. Rolling back the kernel does not
help. Per-boot detail: [`evidence/diagnosis/per-boot-history.txt`](evidence/diagnosis/per-boot-history.txt).

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
evidence/
  baseline/           the failing boot, before any mitigation
  diagnosis/          reproducible transcripts proving the root cause
  sessions/           one directory per reproduction session
HISTORY.md            chronological development record, wrong turns included
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
renamed only after verification passes. The logs in `evidence/baseline/` were produced this way.

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

## Diagnostic tools

Standalone — clone and run, no installation required. All work with any USB Bluetooth
controller, not just `13d3:3503`.

| Tool | Purpose |
|---|---|
| `tools/bt-diagnose` | **Do you have this bug?** Auto-detects the controller, scans all boots, gives a verdict |
| `tools/bt-state` | Current controller/USB/service state in one shot |
| `tools/bt-boots [N]` | Per-boot failure counts across retained boots |
| `tools/bt-boot-list` | Robust journal boot enumeration (see its header — the obvious versions fail silently) |
| `tools/sanitize-logs.sh` | Scrub MACs, BSSIDs, UUIDs and IPv4 from logs before publishing them |

Installed to `/usr/local/bin` by `install.sh`, but none of them need it.

### Investigating a hang

Installed alongside the mitigation, for reproducing and recording failures:

| Tool | Purpose |
|---|---|
| `bt-status` | **"What do we have by now?"** — controller, per-boot history, whether Bluetooth was actually used, watchdog activity, verdict |
| `bt-postmortem` | What happened during the last hang: timing, whether the watchdog fired, **whether the reset worked** |
| `bt-incident <slug>` | Collect a hang that already happened into a sanitised evidence session |
| `bt-timeline [-30m]` | Merge kernel, bluetoothd, watchdog, trace and your marks into one chronology |
| `bt-mark "<text>"` | Annotate the journal with what you are doing, plus device state at that instant |
| `bt-evidence start/note/cmd/stop` | Record a planned session, when you know the test in advance |
| `bt-trace` (service) | Rotating btsnoop HCI capture via `btmon`; logs its own gaps |

See [`evidence/README.md`](evidence/README.md) for how sessions are structured.

## Development helpers

Recurring tasks are scripted at a stable path outside this repo
(`/root/exp/bin`, separately version-controlled) so they can be granted
permission once rather than re-approved as ad-hoc commands:

| Script | Purpose |
|---|---|
| `bt-state` | Bluetooth/USB/service state in one shot |
| `bt-boots [N]` | per-boot failure counts |
| `repo-scan <dir>` | refuse-to-publish scan: MACs, BSSIDs, UUIDs, AI attribution, binary captures |
| `repo-validate <dir>` | `bash -n`, `systemd-analyze`, `udevadm verify`, `jq` |
| `repo-save <dir> "<msg>"` | validate → scan → commit → push → verify remote matches |

## Contributing

Useful data points, especially:

- Other USB IDs showing the same signature (timeouts with zero reset attempts)
- Whether `13d3:3503` is present in the quirks table in current mainline
- Confirmation that the patch works, if you build it

## License

GPL-2.0. See [LICENSE](LICENSE).
