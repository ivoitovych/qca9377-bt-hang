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
