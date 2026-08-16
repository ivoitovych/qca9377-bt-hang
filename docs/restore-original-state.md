# Restoring the machine to its pre-investigation state

A complete, verifiable path back to how this system looked before any of this work
started — broader than `uninstall.sh`, which only reverses what `install.sh` did.

**Short version:** `sudo ./uninstall.sh --apply` covers the mitigation. Four further
changes live outside it (§3–§6). Nothing here is load-bearing for booting: no
bootloader, initramfs, kernel package, partition table or fstab was ever touched.

---

## 1. The starting state, as measured

Captured before the first change was made, on 2026-08-10 at 02:54 CEST:

| Property | Original value |
|---|---|
| `/sys/module/btusb/parameters/enable_autosuspend` | `Y` |
| `/sys/bus/usb/devices/3-3/power/control` | `auto` (delay 2000 ms) |
| `/sys/bus/usb/devices/3-3/power/wakeup` | `disabled` |
| `bluetooth.service` | `active` / `enabled` |
| `/etc/bluetooth/main.conf` | stock — only `AutoEnable=true` set |
| `/etc/modprobe.d/btusb-qca9377.conf` | **did not exist** |
| `/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules` | **did not exist** |
| `tlp` | `inactive`, no `/etc/tlp.conf` |
| journald | persistent (`/var/log/journal` present) |
| Kernel | `7.0.0-28-generic` (unchanged throughout) |

**No pre-existing file was ever modified.** Verified two ways:

```bash
# every backed-up /etc file was byte-identical to live; only ADDED files differed
diff -rq <backup>/etc-bluetooth /etc/bluetooth        # no output
diff -rq <backup>/etc-modprobe.d /etc/modprobe.d      # Only in /etc: btusb-qca9377.conf

# and independently, against the package database:
dpkg --verify bluez                                    # no output = all checksums match
```

That is why restoration is *deletion of added files*, not restoration from backup.

---

## 2. The mitigation — `uninstall.sh`

```bash
sudo ./uninstall.sh                          # dry run, prints the full plan
sudo ./uninstall.sh --apply                  # revert
sudo ./uninstall.sh --apply --purge-metrics  # also delete collected metrics
```

Removes everything `install.sh` adds. **The authoritative list is `install.sh`
itself** — roughly 35 commands, the capture daemons, the shared `lib/` programs, the
units, drop-ins, udev rules, the modprobe conf, `baseline.tsv` and the first-install
stamp; then reloads udev and systemd and restores `enable_autosuspend=Y`. This
paragraph deliberately does not enumerate the files: an earlier version froze an
11-command list here that fell ~24 tools behind the installer while still reading as
complete — the fourth hand-written list this repository has caught rotting
(review 2026-08-15T1752Z §1.10). The mechanical guarantees are elsewhere:
`tests/run-tests` asserts every `install_file` destination appears in
`uninstall.sh`'s list, and `tools/verify-restored.sh` derives its checks from
`install.sh` at run time.

If a drop-in directory still holds files this project did not install — a
`systemctl edit` override of your own, for instance — uninstall now **says so** rather
than leaving it silently behind.

Verify nothing is left with `./tools/verify-restored.sh`.

Verify:

```bash
cat /sys/module/btusb/parameters/enable_autosuspend   # expect Y
systemctl status bt-hang-watchdog                     # expect: not found
ls /etc/modprobe.d/btusb-qca9377.conf                 # expect: no such file
```

⚠️ `enable_autosuspend` only flips back if `btusb` can be reloaded. If the module is in
use the script says so and the change lands at the next boot.

⚠️ `power/control` returns to `auto` only after the device re-enumerates, since the udev
rule applied at hotplug time. A reboot settles it.

---

## 3. Collected metrics — data, not config

`uninstall.sh` deliberately **keeps** `/var/log/bt-health/metrics.tsv` so the
effectiveness record survives a revert.

```bash
sudo rm -rf /var/log/bt-health          # or pass --purge-metrics
```

---

## 4. User-wide Claude Code setting

Changed outside this repo, at `~/.claude/settings.json`, to suppress AI attribution in
commits and PRs. It affects **every project on this machine**, not just this one.

Before:
```json
{ "theme": "dark" }
```

After:
```json
{
  "theme": "dark",
  "attribution": { "commit": "", "pr": "", "sessionUrl": false }
}
```

To restore, delete the `attribution` block. Keeping it is harmless and is probably what
you want; it is listed here only for completeness.

---

## 5. Synthetic log entries ⚠️

Three fabricated lines were written to `/dev/kmsg` at ~03:07 on 2026-08-10 to test the
watchdog's detection path:

```
Bluetooth: hci0: command 0x0406 tx timeout
```

They are indistinguishable from real hardware events in `journalctl -k -b 0`, which now
shows **25** `tx timeout` events where the hardware produced **22**.

- They vanish on reboot (they exist only in this boot's journal).
- The sanitised logs committed in `evidence/baseline/` were captured at 02:54, *before* the
  injection, so the published evidence contains only the 22 genuine events.
- If you quote live journal output anywhere, subtract them or note them.

---

## 6. Things already reverted, or that a reboot clears

| Action | Status |
|---|---|
| `systemctl stop/start bluetooth` | reverted — service `active`/`enabled` |
| USB `unbind`/`bind` on `3-3` | runtime only; cleared by reboot |
| `usb3-port3/disable` toggle | reverted — flag back to `0` |
| `modprobe -r btusb && modprobe btusb` | runtime only |
| `/root/exp/bluepiss` deleted | intentional; contents superseded by this repo |

None of these persist across a reboot.

---

## 7. The published repository

The investigation is public at `https://github.com/ivoitovych/qca9377-bt-hang`.

Restoring the *machine* does not touch it. If you also want the publication undone:

```bash
gh repo delete ivoitovych/qca9377-bt-hang
```

⚠️ Irreversible, and not truly a restoration: forks, clones and search-engine caches can
outlive a deletion. Deleting a public repo is a separate decision from reverting the
system.

---

## 8. Verify

```bash
./tools/verify-restored.sh
```

Checks each item above and reports what is still in place. Run it after
`uninstall.sh --apply` and again after the next reboot, since two of the checks
(`power/control`, synthetic log lines) can only settle once the machine restarts.

---

## 9. What cannot be restored

- **The raw, unsanitised logs** from the failing boot. Their content survives in
  `evidence/baseline/*.sanitized.log`; what is gone is the real MAC addresses, the Wi-Fi AP
  BSSID and the root filesystem UUID. Losing exactly those was the intent.
- **The hardware state.** The controller was already hard-hung when the investigation
  began. A full power-off recovers it. (Whether a warm reboot also does is untested — see EX-017.)
  That predates and is independent of everything documented here.
