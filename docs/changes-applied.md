# Change Protocol — OS modifications made during this investigation

**Host:** `n` (Ubuntu 24.04.4 LTS, kernel 7.0.0-28-generic)
**Date:** 2026-08-10
**Rollback script:** `./uninstall.sh` (reverses everything in §2)
**Config backup:** local only, not published (see `docs/changes-applied.md` §5)

---

## 0. Summary of blast radius

**Every persistent change is a NEW file. No pre-existing file was modified or deleted.**

That makes rollback trivial and total: delete the installed files, drop the unit
symlinks, reload two daemons — see §5, or just run `./uninstall.sh --apply`. Nothing touched disk layout, the bootloader, GRUB, initramfs, kernel packages,
fstab or any existing config. **There is no bootability risk from any change here.**

| Category | Touched? |
|---|---|
| Bootloader / GRUB / initramfs | ❌ no |
| Kernel packages, `/boot` | ❌ no |
| Partitions, fstab, disk | ❌ no |
| Existing config files | ❌ no — none modified |
| New files added | ✅ 9 (+1 for a non-default device) |
| systemd units enabled | ✅ 2 |

---

## 1. Files created (persistent)

**Mitigation:**

| # | Path | Purpose | Perms |
|---|---|---|---|
| 1 | `/usr/local/sbin/bt-hang-watchdog` | Watchdog script — detects controller timeouts, issues USB reset | `0755` |
| 2 | `/etc/systemd/system/bt-hang-watchdog.service` | systemd unit for the above | `0644` |
| 3 | `/etc/modprobe.d/btusb-qca9377.conf` | `options btusb enable_autosuspend=0` | `0644` |
| 4 | `/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules` | Pin `power/control=on` for `13d3:3503` | `0644` |

**Effectiveness measurement:**

| # | Path | Purpose | Perms |
|---|---|---|---|
| 5 | `/usr/local/sbin/bt-health-snapshot` | Appends a metrics row to `/var/log/bt-health/metrics.tsv` | `0755` |
| 6 | `/etc/systemd/system/bt-health-snapshot.service` | oneshot unit for the above | `0644` |
| 7 | `/etc/systemd/system/bt-health-snapshot.timer` | every 15 min + 2 min after boot (monotonic) | `0644` |
| 8 | `/usr/local/bin/bt-health-report` | effectiveness analysis command | `0755` |
| 9 | `/usr/local/share/qca9377-bt-hang/baseline.tsv` | pre-mitigation counts, for comparison | `0644` |

Installed **only when a non-default controller is targeted** (`BT_VID`/`BT_PID`):

| # | Path | Purpose | Perms |
|---|---|---|---|
| 10 | `/etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf` | `Environment=BT_VID/BT_PID` override | `0644` |

Plus symlinks created by `systemctl enable`:

```
/etc/systemd/system/multi-user.target.wants/bt-hang-watchdog.service
    -> /etc/systemd/system/bt-hang-watchdog.service
/etc/systemd/system/timers.target.wants/bt-health-snapshot.timer
    -> /etc/systemd/system/bt-health-snapshot.timer
```

And one data directory (**not** removed by rollback unless `--purge-metrics` is passed):

```
/var/log/bt-health/metrics.tsv
```

Journald was **not** reconfigured — `/var/log/journal` already exists and 35 boots are
retained, which is sufficient for cross-boot comparison.

---

## 2. Commands executed that changed persistent state

In order:

```bash
# --- file creation (see §1) ---

# --- activation ---
udevadm control --reload-rules          # reload udev ruleset
modprobe -r btusb                       # unload (usecount was 0, device already absent)
modprobe btusb                          # reload -> picks up enable_autosuspend=0
systemctl daemon-reload
systemctl enable --now bt-hang-watchdog # create symlink + start service
```

### Before / after state

| Setting | Before | After |
|---|---|---|
| `/sys/module/btusb/parameters/enable_autosuspend` | `Y` | `N` |
| `/sys/bus/usb/devices/3-3/power/control` | `auto` (2000 ms) | `on` (applies on next enumeration) |
| `bt-hang-watchdog.service` | did not exist | `enabled`, `active (running)` |

---

## 3. Runtime-only actions (NOT persistent — reset by any reboot)

These were part of the investigation and recovery attempts. **None survive a reboot.**

| Action | Effect | Reverted? |
|---|---|---|
| `systemctl stop bluetooth` → later `start` | service bounce | ✅ back to `active` |
| `echo 3-3 > /sys/bus/usb/drivers/usb/unbind` then `bind` | USB re-enumeration attempt | n/a — device did not return (already hard-hung) |
| `echo 1 > usb3-port3/disable`, then `echo 0 >` | port power-cycle attempt | ✅ flag back to `0` |
| `echo "Bluetooth: hci0: command 0x0406 tx timeout" > /dev/kmsg` ×3 | synthetic log lines to test watchdog detection | n/a — log noise only, no side effects |

⚠️ **Note on the synthetic messages:** three fake `tx timeout` lines were written to the
kernel log at ~03:07 on 2026-08-10 to verify the watchdog fires. When reading logs later,
do not mistake these for genuine hardware events. They are the only fabricated entries.

---

## 4. What is verified vs. unverified ⚠️

**Verified working:**
- Script parses (`bash -n`), unit validates (`systemd-analyze verify`), udev rule
  validates (`udevadm verify`: 1 checked, 0 fail)
- Service starts, runs, correctly detects that the controller is already hard-hung
- Full detection chain, end-to-end, via injected `/dev/kmsg` messages:
  threshold logic → intervention → correct hard-hang diagnosis → failure counting
- `enable_autosuspend` flipped `Y` → `N`, confirmed by reading sysfs

**NOT yet verified — cannot be, until the hardware is revived:**
- ⚠️ The actual **recovery path** (`USBDEVFS_RESET` → unbind/bind → controller returns).
  The chip is currently off the bus, so the success branch has never executed.
- ⚠️ The udev rule taking effect. It fires on `ACTION=="add"`, and no `add` event can
  occur until the device re-enumerates after a cold power-off.

**Both require a full power-off to test.** After that, confirm with:

```bash
cat /sys/bus/usb/devices/3-3/power/control     # expect: on
cat /sys/module/btusb/parameters/enable_autosuspend   # expect: N
systemctl status bt-hang-watchdog              # expect: active, "device present at 3-3"
```

---

## 5. Rollback

> For the complete picture — including the changes this document does not cover, such as
> collected metrics and settings changed outside the repo — see
> [`restore-original-state.md`](restore-original-state.md), and verify with
> `./tools/verify-restored.sh`.


### Automatic

```bash
./uninstall.sh          # dry run: shows what it would do
./uninstall.sh --apply  # actually revert
```

### Manual — the complete set

```bash
# units
systemctl disable --now bt-hang-watchdog
systemctl disable --now bt-health-snapshot.timer

# watchdog
rm -f /usr/local/sbin/bt-hang-watchdog
rm -f /etc/systemd/system/bt-hang-watchdog.service
rm -f /etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf
rmdir --ignore-fail-on-non-empty /etc/systemd/system/bt-hang-watchdog.service.d

# autosuspend
rm -f /etc/modprobe.d/btusb-qca9377.conf
rm -f /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules

# metrics collector
rm -f /usr/local/sbin/bt-health-snapshot
rm -f /usr/local/bin/bt-health-report
rm -f /etc/systemd/system/bt-health-snapshot.service
rm -f /etc/systemd/system/bt-health-snapshot.timer
rm -f /usr/local/share/qca9377-bt-hang/baseline.tsv
rmdir --ignore-fail-on-non-empty /usr/local/share/qca9377-bt-hang
# collected data (optional):
# rm -rf /var/log/bt-health

systemctl daemon-reload
udevadm control --reload-rules
modprobe -r btusb && modprobe btusb     # restores enable_autosuspend=Y
```

⚠️ Omitting the metrics units — as an earlier version of this list did — leaves
`bt-health-snapshot.timer` enabled and firing every 15 minutes after an otherwise
"complete" manual rollback.

### Partial rollback

The two measures are independent — you can revert one and keep the other:

- **Watchdog only:** `systemctl disable --now bt-hang-watchdog` (leave the files; harmless)
- **Autosuspend only:** delete files 3 and 4, then `udevadm control --reload-rules` and
  reload `btusb`

### Restoring original config files

Not required — no original file was modified. The backup at
the local backup directory exists purely as insurance and can be diffed at any time:

```bash
diff -r <backup-dir>/etc-bluetooth /etc/bluetooth
diff -r <backup-dir>/etc-modprobe.d /etc/modprobe.d
```

(The second will show `btusb-qca9377.conf` as the only addition.)

---

## 6. Tuning the watchdog without editing files

```bash
systemctl edit bt-hang-watchdog
```

Defaults, and what they mean:

| Variable | Default | Meaning |
|---|---|---|
| `BT_THRESHOLD` | `3` | timeouts inside the window before intervening |
| `BT_WINDOW` | `60` | sliding window, seconds |
| `BT_COOLDOWN` | `180` | minimum seconds between recovery attempts |
| `BT_MAX_FAILS` | `3` | consecutive failures before going idle until reboot |

⚠️ Corrected 2026-08-11: an earlier note here claimed the kernel uses a threshold of 5
consecutive timeouts. It does not — `hci_cmd_timeout()` calls `hdev->reset()` on the
first one, with no threshold.
`3` is deliberately more aggressive, because on this host the soft-hang window is the
only chance to recover and there is no downside to resetting an already-broken radio.

Watch it work:

```bash
journalctl -u bt-hang-watchdog -f
```

---

## 2026-08-12 — logging depth increase (Phase 18a)

Four new sources, added because reconstructing a test session from the journal showed
that the layer between "the operator did something" and "the controller stopped
answering" was almost entirely unrecorded.

| Change | File | Effect | Revert |
|---|---|---|---|
| kernel dynamic debug | `/usr/local/sbin/bt-dyndbg` + `bt-dyndbg.service` | 214 `pr_debug` sites in `btusb.c`, `hci_core.c`, `hci_sync.c`, `hci_conn.c` | `bt-dyndbg off`, or disable the unit |
| bluetoothd debug | `/etc/systemd/system/bluetooth.service.d/10-debug.conf` | `bluetoothd -d`: connect, disconnect, pairing, profile transitions | delete file, `daemon-reload` |
| USB transport capture | `/usr/local/sbin/bt-usbmon` + `bt-usbmon.service` | rotating pcap of the controller's USB bus | disable the unit |
| journal size cap | `/etc/systemd/journald.conf.d/10-bt-investigation.conf` | `SystemMaxUse=16G`, `SystemKeepFree=20G` | delete file, restart `systemd-journald` |

Also: `bt-trace` retention raised from 30 files to 400. The count was never the real
bound — `btmon` in bluez 5.72 aborts frequently and each abort forces a rotation, so the
average file is ~2 MB rather than the 128 MB rotation threshold, and 30 files bought
hours rather than days. The free-space floor is the actual bound.

### What is deliberately NOT enabled

`hci_event.c` (196 sites) and `l2cap_core.c` (168 sites) fire per received HCI event and
per L2CAP packet. During A2DP playback that is hundreds of lines per second. They are
excluded for two reasons, and the second matters more than the first: the volume is
unaffordable, and the logging work itself lands on the receive path of a bug that is
characterised by timing. Measurements taken with them enabled would not be comparable to
the baseline taken without.

Enable them deliberately and temporarily when a specific question needs them:

```bash
bt-dyndbg on --packets     # and turn it off again afterwards
```

### ⚠️ Data loss during this change

The journal drop-in initially also set `MaxRetentionSec=1month`. That is not a bound — it
is an instruction to delete anything older, acted on at journald restart. It permanently
removed every boot before 2026-07-12, taking the hang history from **34 boots to 18**, in
a change whose purpose was to retain more. The files are unrecoverable.

`MaxRetentionSec` has been removed and the file now carries a warning against
reintroducing it. `SystemMaxUse` discards oldest-first only on reaching the cap;
`MaxRetentionSec` discards immediately and unconditionally.

The 34-boot dataset survives in `evidence/exhibits/003-desync-is-not-the-cause.md`,
captured nine minutes earlier. That exhibit is annotated as no longer re-runnable.

---

## 2026-08-12 (later) — capture that survives, trials that arm themselves

| Change | File | Effect | Revert |
|---|---|---|---|
| Decode-free HCI capture | `/usr/local/sbin/bt-capture` + `bt-capture.service` | rotating btsnoop written without decoding, so btmon's decoder crash cannot end it | disable the unit |
| Auto-opened trials | `bt-trial-auto.service` | opens a trial each boot before `bluetooth.service`; closed by the watchdog on a hang or by systemd at shutdown | disable the unit |
| SCO parameter reader | `/usr/local/bin/bt-sco` | pairs each synchronous setup with its completion and decoded parameters | remove the file |
| Log volume reporter | `/usr/local/bin/bt-logvolume` | what is filling the kernel log, and at what rate | remove the file |
| Per-packet debug suppressed | `/usr/local/sbin/bt-dyndbg` | four more hot sites switched off; 174 → 166 active | `bt-dyndbg on --packets` |

Capture directories are root-only (`0700`, `UMask=0077`): HCI captures contain link keys
and device addresses.

### ⚠️ A documented change that was never in effect

`bin/bt-trace`'s `KEEP` default was raised 30 → 400 earlier that day and recorded here as
done. It was not: `bt-trace.service` sets `BT_TRACE_KEEP=30` explicitly, which silently
overrode the default. **The service kept 30 files the whole time while this document
claimed 400**, and the btsnoop captures for a session under active investigation were
rotated away roughly nine hours before anyone looked for them.

Now set in the unit, where it takes effect, and verified:

```console
$ systemctl show bt-trace -p Environment --value
BT_TRACE_DIR=/var/log/bt-health/trace BT_TRACE_MAX_MB=128 BT_TRACE_KEEP=400 BT_TRACE_MIN_FREE_GB=15
```

The free-space floor was raised 10 → 15 GB at the same time; it is enforced on every check
regardless of the file count, and is the bound that cannot be wrong.

**Rule taken from this:** a change to a default is not applied until the value *in effect*
has been read back. Record the verification command alongside the change, not the intent.

---

## 2026-08-12 (later still) — probe provenance

| Change | File | Effect | Revert |
|---|---|---|---|
| Event-triggered snapshot unit | `/etc/systemd/system/bt-health-snapshot-event.service` | identical script under a second unit name, so the journal records *why* each probe fired | delete file, `daemon-reload` |
| udev now targets it | `/etc/udev/rules.d/51-bluetooth-health-snapshot.rules` | 4 `RUN+=` lines point at the `-event` unit | reinstall from the checkout |
| Capture-path comparison | `/usr/local/bin/bt-capdiff` | agreement/disagreement between the two HCI capture paths | remove the file |
| Exposure analysis | `/usr/local/bin/bt-phase` | failure phase within the probe cycle, exogenous probes only | remove the file |

### Why the units were split

`bt-health-snapshot` runs from two sources with completely different epistemic status: a
15-minute timer whose schedule is independent of Bluetooth state, and a udev rule that fires
on `bluetooth`/`usb` add and remove — the very events a failing controller generates.

Running both through one unit made them indistinguishable in the journal. Analysing them as
a single exposure clock produced an apparently dramatic observer effect (mean phase 0.084,
6 of 8 failures in the first 10% of their gap) which was entirely an artifact of
outcome-dependent timestamps. See `EX-012`.

Endogenous probes are **not** disabled or discarded. They are useful chronology. They simply
cannot define a null exposure distribution.

**Verification** — provenance is only recorded from the split onward, so `bt-phase` checks
its own precondition and refuses on older data:

```console
$ bt-phase -b 0
⛔ PROVENANCE CHECK FAILED — refusing to report a phase statistic.
  95 of the 140 probes claimed exogenous are less than 450s apart,
  but the timer period is 900s. They cannot all be timer-driven.
```

That is the intended behaviour on pre-split boots, not a fault.

### Known limitation, recorded rather than accepted

The probe timestamps are **execution** times, not scheduled due times. A timer invocation
delayed by system load — or by controller trouble — moves the measuring ruler in a direction
the system under study can influence. Reconstructing due times from `OnUnitActiveSec` is the
next refinement and is not yet done.


---

## 2026-08-13 — shared awk programs

| Change | File | Effect | Revert |
|---|---|---|---|
| Shared civil-date arithmetic | `/usr/local/bin/lib/timestamp.awk` | one `iso_secs()` for every analysis tool | removed by `uninstall.sh` |
| Interval helper | `/usr/local/bin/lib/interval.awk` | seconds between two ISO timestamps | as above |
| Capture-path matcher | `/usr/local/bin/lib/capdiff-match.awk` | one-to-one pairing for `bt-capdiff` | as above |

These are data files, not executables, and they must live in `<dir of the tool>/lib`
because the tools load them with `awk -f`. `uninstall.sh` removes them and then removes
`/usr/local/bin/lib` if empty.

**Why they exist as files rather than inline.** `awk -f lib.awk 'program' input` does not
run `'program'` — with `-f` present, awk takes the program only from the `-f` files and
treats the positional string as an input filename. Inlining a program alongside a shared
`-f` library silently disables it. `tests/run-tests` asserts no tool does this.
