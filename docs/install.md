# Installing the mitigation tooling, and what each piece does

> Moved from the front page on 2026-09-18 (front-door review `FD-01`), unchanged apart
> from this banner. The watchdog and the `BT_EARLY` mode described here are **experiments
> inside the investigation, not its result**: on this controller the USB reset the watchdog
> performs has three controlled demonstrations of driving an already-wedged device off the USB bus until power is removed (`EX-023`,
> `EX-026`), and the precursors `BT_EARLY` acts on have been refuted as causal markers. The
> current state of the fault is `BRIEF.md`; the front page `README.md` summarises it.
> The figures quoted below (34 boots, 287 timeouts, five late resets, the lead-time table)
> are historical measurements from August 2026 and are kept as the record of how the
> tooling was designed, not as current findings.

## Install

```bash
git clone https://github.com/ivoitovych/qca9377-bt-hang   # or your fork
cd qca9377-bt-hang
sudo ./install.sh            # dry run — shows exactly what it would do
sudo ./install.sh --apply    # install and arm
```

### `--tools-only` — deploy the files, arm nothing

```bash
sudo ./install.sh --tools-only
```

Installs every file, enables no service, reloads no driver, touches no device.

**Use it on a machine you are measuring.** `--apply` runs
`systemctl enable --now bt-hang-watchdog`, and that watchdog answers an HCI
timeout with a USB reset — an operation with three controlled demonstrations of
driving an already-wedged controller off the USB bus until power is removed (`EX-023`, `EX-026`). On the investigation machine
that made the choice "stale instruments or an armed watchdog", and the
instruments stayed 29 versions behind for days as a result. This is the third
option.

It is deny-by-default: only `install`, `rm`, `rmdir` and `mkdir` run, and every
other command is printed with the reason it was skipped, so a system command
added later is skipped rather than silently executed.

⚠️ What it deliberately does **not** do: an updated unit file for an
already-running service is not re-read until the next boot, and a changed udev
rule applies at the next enumeration. The files on disk are current either way.
**If a unit file changed** (for example `bt-trial-auto.service` gained
`TimeoutStopSec=30` on 2026-09-19), run `sudo systemctl daemon-reload` after
`--tools-only` or the manager keeps the old definition until reboot — and check
with `systemctl show bt-trial-auto -p TimeoutStopUSec`.

Uninstall is a restoration: every installed file is new, and where a destination
already existed and was not ours, `install.sh` kept the original as
`<file>.pre-qca9377-bt-hang` and `uninstall.sh` moves it back (since 2026-09-20; before
that a colliding file was overwritten and then deleted):

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
rule pinning `power/control=on`. This is an experimental mitigation, not an established
mechanism: the repository has not measured that autosuspend triggers the controller wedge or changes its
frequency, and `EX-014` records uncertainty about the original runtime value.

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

Report these outcomes separately rather than converting them into one success verdict:

- **tx-timeout counts change under a controlled denominator** — evidence about incidence,
  not proof of which treatment component caused the change
- **timeouts still happen, but each is followed by `RECOVERED`** — the watchdog is doing
  useful mitigation for a confirmed HCI stall
- **USB errors/disappearance follow intervention** — an adverse post-intervention outcome;
  it does not prove the controller naturally reached a second stage or that the watchdog
  merely acted too late

Do not lower thresholds on the assumption that USB absence is natural progression. A
reset at +0 s may help or harm; that sign remains an experiment, not a tuning fact.

Baseline for comparison (`evidence/baseline/baseline.tsv`): **287 timeouts across 34 boots, 13 of 34
boots hung.**

⚠️ **That baseline is no longer re-derivable.** It was read from boots that have since
rotated out of the journal under `SystemMaxUse`, so the numbers survive in the TSV as a
record but a reviewer cannot reproduce them. `tools/bt-retention` reports which exhibits
remain re-derivable; `docs/bug-report.md` withdraws both figures from its load-bearing
list rather than restating them.

Longest untreated observation to date: **47338.1 s — 13 h 8 m 58 s** with zero USB-layer
lines and zero interventions (`EX-029`).

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

Trigger patterns were selected from historical boot-level associations, written as
*appearances in boots that hung / appearances overall*: `cancel_request() Suspend` 2/2,
`Abort` 4/4, `avdtp_connect_cb` 5/5, `SDP record: Host is down` 10/10,
`avdtp_close failed` 3/4. `Device or resource busy` is excluded at 3/9 — too noisy.

⚠️ These ratios are **historical and no longer re-derivable**: the boots they were
counted over predate the 2026-08-12 journal-retention accident (see `EX-003` for the
same caveat class), and the extraction was never captured as an exhibit. An earlier
wording of this paragraph reversed the notation and transposed `avdtp_close failed`
(review 2026-08-15T1752Z §1.1); the order used by `HISTORY.md` Phase 12 ("4/4
occurrences fell in boots that hung") is the one stated above. They are retained only
to explain how the heuristic's patterns were chosen — see the matching comment in
`bin/bt-hang-watchdog`.

Those ratios are **not predictive precision**. An early reset prevents observation of the
counterfactual, and every proposed early marker has failed causal tests elsewhere in this
repository. The mode is an aggressive mitigation heuristic, not evidence the wedge was imminent.

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

`BT_EARLY` can leave the controller answering after an intervention, but cannot say whether
the wedge would otherwise have occurred. It is off in experiment mode for that reason.

> ⚠️ **These are log signatures, not controlled comparisons.** The reproductions were
> ad-hoc — arbitrary connect/disconnect/mode-change activity, no fixed procedure, exact
> actions unrecorded. Differences between incidents may reflect different (unknown)
> actions rather than different mechanisms. See
> [`docs/bug-report.md`](docs/bug-report.md#-methodological-caveat--read-before-weighing-the-comparisons).

---
