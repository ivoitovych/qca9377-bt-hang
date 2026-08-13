# qca9377-bt-hang

**Your Bluetooth dies after a while and only a full power-off brings it back.**

Affects Qualcomm Atheros **QCA9377** (ROME) Bluetooth, USB ID `13d3:3503`, on Linux.

This repository is an **open investigation**, not an explanation. It ships
diagnostics and a userspace watchdog that mitigates the failure; it does not yet
know why the failure happens. What is currently established:

> The controller sometimes enters a non-responsive HCI state during
> synchronous-audio (SCO/eSCO) link transitions. Generic USB transport failure
> follows about 31 seconds later rather than initiating the event.

That is a statement about **when and where**, not **why**. The mechanism is not
established, and several confident-sounding explanations in this repository's
history have already been refuted — by this repository. See
[`docs/issues.md`](docs/issues.md) for what is currently believed and what has
been killed, and [`HISTORY.md`](HISTORY.md) for how each wrong turn was found.

⚠️ **Sections below this point were written earlier and are being rewritten.**
Where a section states a cause ("the trigger", "the real fix", "this is the
bug"), treat `docs/issues.md` as authoritative — it is kept current and this
front page is not yet.

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
  automatic reset attempts  : 0        <-- a real gap; not established as the cause
```

Timeouts with **zero** resets means the kernel logged the failures and did nothing.
`hci_cmd_timeout()` calls `hdev->reset(hdev)` on the first timeout — but `hdev->reset` is
only installed for devices matched by btusb's vendor quirks table. For an unmatched
device it is NULL, so the branch is never taken.

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

Point 4 is a real gap in the driver (`BT-3`), but has NOT been shown to cause the hang. Point 2's `errors:0` means **no errors are reflected in those HCI
counters** — the chip is accepting bytes and simply not answering. (USB health at this
stage is established separately, from USB-level evidence: descriptor reads still succeed
until stage 2.)

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

### Observed two-stage failure, and the missing reset path

The controller fails in two stages:

| Stage | State | Recoverable? |
|---|---|---|
| 1 — soft | HCI unresponsive, USB fine | observed **once** to recover transiently; durability unknown (`EX-004`) |
| 2 — hard | USB core unresponsive, device drops off the bus | **no** — cold power-off only |

⚠️ It is tempting to write "with the quirk, a reset fires within seconds and you notice
nothing but an audio dropout" — an earlier version of this file did. That is **not
established**. The one early reset ever measured did recover the controller, and it failed
again 132 seconds later (`EX-004`). A reset at the exact moment `hdev->reset` would fire —
the first HCI timeout — has still never been tested. See `docs/fix-proposal.md` §5a.

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

### An earlier hypothesis about the trigger — SINCE REFUTED

> ⚠️ Kept for the record. The A2DP-teardown trigger described below does not
> hold: the transport reached IDLE five times in one boot with no SCO setup and
> no failure. See `docs/issues.md` BT-1 and `EX-007`.

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
`USBDEVFS_RESET`, escalating to USB unbind/bind if needed.

⚠️ This is a **proxy, not an equivalent**. `USBDEVFS_RESET` goes via `proc_resetdevice()`
→ `usb_reset_device()`, while the kernel path queues a reset on the interface
(`usb_queue_reset_device()`). More importantly the *timing* differs: the kernel resets at
+0 s inside `hci_cmd_timeout()`, whereas a journal-tailing watchdog has measured +11 s to
+33 s. Every late reset failed; the +0 s case has never been tested.

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
| `BT_EARLY_THRESHOLD` | `1` | early signals before intervening |
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

**The warning is short and its length varies wildly.** Measured lead times between the
first bluetoothd signal and the first HCI timeout:

| Incident | Lead time |
|---|---|
| audio teardown | −52 s |
| audio teardown (recovered) | enough for ≥2 signals |
| connect/disconnect + mode changes | **+133 s** — no window at all |
| "a few manipulations" | **−7 s** |
| light use, 2 min into a fresh boot | **none at all** |

**Two of five hangs had no usable warning**, so this is not a general mitigation — it
covers roughly the audio-teardown subset. The late trigger has never once succeeded:
five for five, a reset after the first HCI timeout failed.

That is why the default threshold is **1**, not 2. On 2026-08-11 exactly one signal
arrived 7 s ahead, a threshold of 2 was never reached, and the controller was lost.
A 7-second window also sets a hard bound on how slow *any* recovery mechanism can
afford to be — including a kernel one.

⚠️ **In two of five hangs there was no usable warning at all**, so `BT_EARLY` cannot be
relied on. In one, bluetoothd's signal arrived **133 s *after*** the first HCI timeout;
in another it never appeared.

`BT_EARLY` seems to help when the failure is preceded by audio-layer trouble, and cannot
help when the stall reaches HCI first. Enable it if your logs show AVDTP errors before
the timeouts; expect nothing from it otherwise.

> ⚠️ **These are log signatures, not controlled comparisons.** The reproductions were
> ad-hoc — arbitrary connect/disconnect/mode-change activity, no fixed procedure, exact
> actions unrecorded. Differences between incidents may reflect different (unknown)
> actions rather than different mechanisms. See
> [`docs/bug-report.md`](docs/bug-report.md#-methodological-caveat--read-before-weighing-the-comparisons).

---

## A candidate fix — NOT established as the fix

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
> The window closes sharply; where exactly, relative to the first timeout, is unknown —
> because no experiment has yet put a reset there.
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
tools/                diagnostics, incident capture, log sanitiser
tests/                run-tests — the analysis invariants
  fixtures/           table-driven cases for the awk libraries
  journal/            canned journals for driving tools without a machine
devtools/             contributor tooling (check, scan, validate, coverage, commit+verify)
reviews/              assessments of the repository itself
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
| Device unmatched by btusb quirks table | ✅ upstream v7.0 source **and** shipped binary |
| Reset mechanism is `hdev->reset`, on the first timeout | ✅ source + binary |
| Failure localised to synchronous-audio link transitions | ⚠️ both instrumented failures occur there — setup unanswered in one (`EX-006`), teardown in the other (`EX-009`). **No single triggering opcode**: three SCO setups were survived |
| USB healthy at HCI failure | ✅ measured — first URB error is 31 s later (`EX-008`) |
| Watchdog detection | ✅ tested end-to-end |
| Watchdog recovery path | ✅ exercised — succeeds early, fails once timeouts begin |
| Autosuspend setting, udev rule | ✅ applied and verified |
| **Quantified reproducer (A4)** | ❌ **gate — not done.** No controlled denominator yet |
| Observational denominator | ⏳ accruing — every boot is now a trial, opened automatically |
| Kernel patch | ❌ written, not built or tested |

> ⛔ **Before submitting anything upstream**, work through
> [`docs/pre-submission-checklist.md`](docs/pre-submission-checklist.md): unmet evidence
> gates, content that must be excluded, and a deferred purge of Bluetooth addresses from
> git history.

**This is not one bug.** [`docs/issues.md`](docs/issues.md) tracks six distinct defects
observed on this machine, separately, because filing them under one heading actively
slowed the work — evidence for one kept being read as evidence for another. Two of them
(`BT-2`, the panel-triggered 16 s command desync, and `BT-4`, `btmon` aborting mid-capture)
are reportable **now**, independently of the hang.

**The strongest current lead**, stated at the strength the evidence supports: the
failure occurs during synchronous-audio (SCO/eSCO) link transitions. It is *not* a single
command — three setups were serviced correctly and survived, one went unanswered, and one
completed successfully before a later `Disconnect` went unanswered instead. What the two
failures share is the transition and the USB alternate-setting switch that accompanies it,
not an opcode.

Earlier drafts named an A2DP-idle trigger and then a specific SCO setup command. Both were
refuted here; see `docs/issues.md` BT-1.

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
| `bt-trial` | Numbered trials with a failure rate per build, so every comparison has a denominator. **A trial now opens automatically at each boot** (`bt-trial-auto.service`, ordered before `bluetooth.service`) and is closed by the watchdog on a hang or by systemd at shutdown — a manually started trial missed the window that mattered, because Bluetooth is scanning before anyone can reach a terminal. Auto trials record `survived` rather than `ok`: they say the machine did not hang, not that the reproduction protocol was carried out |
| `bt-capture` (service) | Decode-free HCI capture straight from the kernel monitor socket. Runs alongside `bt-trace` because `btmon` aborts frequently (`BT-4`) and took the SCO parameters with it |
| `bt-sco` | Every synchronous-link setup with its decoded parameters and completion — the comparison that matters now that SCO setup alone is known not to be sufficient |
| `bt-status` | **"What do we have by now?"** — controller, per-boot history, whether Bluetooth was actually used, watchdog activity, verdict |
| `bt-verify-install` | is the running system the same as the checkout? catches hand-installed drift |
| `bt-postmortem` | What happened during the last hang: timing, whether the watchdog fired, **whether the reset worked** |
| `bt-incident <slug>` | Collect a hang that already happened into a sanitised evidence session |
| `bt-timeline [-30m]` | Merge kernel, bluetoothd, watchdog, trace and your marks into one chronology |
| `bt-mark "<text>"` | Annotate the journal with what you are doing, plus device state at that instant |
| `bt-evidence start/note/cmd/stop` | Record a planned session, when you know the test in advance |
| `bt-trace` (service) | Rotating btsnoop HCI capture via `btmon`; logs its own gaps |
| `bt-actions` | **Reconstruct what actually happened** — merges operator actions, BlueZ/PipeWire responses, controller failures and watchdog decisions into one wall-clock timeline, collapsing repeats. Use this instead of describing a session from memory |
| `bt-context` | The inverse filter: shows what sits *next to* a failure that nothing yet explains. Finds signals nobody thought to grep for |
| `bt-boot-stats` | One row per boot, and the cross-tab that tells you whether a signature actually predicts the hang or just accompanies it |
| `bt-exhibit` | Capture evidence as a numbered exhibit: claim, exact extraction command, verbatim output, relevance — command and output captured in one pass so they cannot drift |
| `bt-dyndbg on\|off\|status` | Kernel `pr_debug` for `btusb` and the HCI core. `--packets` adds the per-packet files, which perturb the timing being measured |
| `bt-usbmon` (service) | Rotating pcap of the controller's USB bus — the only record of stage 2, where the kernel logs that a request went unanswered but not what was on the wire |

See [`evidence/README.md`](evidence/README.md) for how sessions are structured.

## Contributing tooling

[`devtools/`](devtools/) holds scripts for working **on** this repository — not for
diagnosing Bluetooth:

| Script | Purpose |
|---|---|
| `devtools/check` | the one command to run before committing |
| `devtools/repo-scan <dir>` | refuse-to-publish scan: MACs, BSSIDs, UUIDs, IPv4, emails, AI attribution, binary captures |
| `devtools/repo-validate <dir>` | `bash -n`, `systemd-analyze`, `udevadm verify`, `jq`, `py_compile` |
| `devtools/repo-save <dir> "<msg>"` | validate → scan → commit → push → verify the remote hash matches |
| `devtools/coverage` | how much of the shipped shell the test suite actually executes |
| `devtools/assert-test-catches` | prove a test really fails when its invariant is broken |

This repo publishes logs, and kernel logs carry the Wi-Fi AP BSSID — which public
geolocation databases index. `repo-scan` is the last check before that leaves the
machine. Not installed by `install.sh`.

### Tests

```bash
tests/run-tests                    # 96 invariants, ~2 s
tests/run-tests --section "stage2" # one block, without a sed range
devtools/coverage                  # what fraction of the shell those 96 actually run
```

Each of the 96 invariants in `tests/run-tests` encodes a defect that really shipped
here, with a fixture built so the old behaviour fails it. Coverage of the shipped shell
is **18.3%**, up from 13.1% when it was first measured; 38 of 44 scripts still execute no
line under test, because most tools call `journalctl` directly and so cannot be driven
from a fixture. Tools that read the journal through
[`tools/lib/journal.sh`](tools/lib/journal.sh) can be:

```bash
BT_JOURNAL_FIXTURE=tests/journal/provenance tools/bt-boot-provenance
```

[the unit-testing assessment](reviews/2026-08-13T1214Z-unit-testing-assessment.md) measures this
and tracks what remains.

## Contributing

Useful data points, especially:

- Other USB IDs showing the same signature (timeouts with zero reset attempts)
- Whether `13d3:3503` is present in the quirks table in current mainline
- Confirmation that the patch works, if you build it

## License

GPL-2.0. See [LICENSE](LICENSE).
