#!/bin/bash
# Collect every local record of BT-17 (2026-11-12 18:03) into the git-ignored incident archive.
# Read-only on the machine: journal, sysfs, package database, capture files. Nothing touches the controller.
set -u
D=/root/exp/qca9377-bt-hang/archive/incidents/20261112-bt17-controller-off-bus
mkdir -p "$D/journal" "$D/captures" "$D/machine"

# Full journals of the boot before (power-off at 17:52), the failing boot, the current boot.
for b in -2 -1 0; do
  id=$(journalctl --list-boots --no-pager | awk -v b="$b" '$1==b {print $2}')
  journalctl -b "$b" --no-pager -o short-precise > "$D/journal/boot${b}-${id}-all.txt"
  journalctl -b "$b" --no-pager -o short-precise _TRANSPORT=kernel > "$D/journal/boot${b}-${id}-kernel.txt"
  journalctl -b "$b" --no-pager -o short-precise -u bluetooth > "$D/journal/boot${b}-${id}-bluetooth-unit.txt"
  # Export format keeps every field, for later fine-grained filtering (journalctl --file after systemd-journal-remote, or plain parsing).
  journalctl -b "$b" --no-pager -o export | zstd -q -19 -T0 -o "$D/journal/boot${b}-${id}-export.zst"
done
journalctl --list-boots --no-pager > "$D/journal/list-boots.txt"

# Every HCI capture written since the start of boot -2 (15:49), both capture paths.
find /var/log/bt-health/capture /var/log/bt-health/trace -type f -newermt "2026-11-12 15:48" -print0 |
  while IFS= read -r -d '' f; do
    zstd -q -19 -T0 -o "$D/captures/$(basename "$f").zst" "$f"
  done

# Machine state at collection time.
{
  echo "collected $(date -u +%Y-%m-%dT%H:%M:%SZ)"; uname -a; cat /proc/cmdline
} > "$D/machine/uname-cmdline.txt"
lsusb > "$D/machine/lsusb.txt"
lsusb -t > "$D/machine/lsusb-tree.txt"
ls -l /sys/bus/usb/devices/ > "$D/machine/usb-devices.txt"
for a in connect_type disable early_stop over_current_count quirks state; do
  f=/sys/bus/usb/devices/usb3/3-0:1.0/usb3-port3/$a
  [ -e "$f" ] && echo "$a: $(cat "$f" 2>&1)"
done > "$D/machine/usb3-port3.txt"
ls -la /sys/class/bluetooth/ /sys/class/rfkill/ > "$D/machine/bluetooth-rfkill-sysfs.txt" 2>&1
for r in /sys/class/rfkill/rfkill*; do echo "$r $(cat "$r/name") hard=$(cat "$r/hard") soft=$(cat "$r/soft")"; done >> "$D/machine/bluetooth-rfkill-sysfs.txt"
ls -l /boot /lib/modules > "$D/machine/kernels.txt"
dpkg -l 'linux-image-*' 'linux-modules-*' bluez 'pipewire*' wireplumber 'gvfs*' > "$D/machine/dpkg-selected.txt"
cp -p /var/log/apt/history.log "$D/machine/apt-history.log"
grep -h "" /etc/modprobe.d/*btusb* /etc/udev/rules.d/*bluetooth* > "$D/machine/btusb-modprobe-udev-disabled.txt" 2>&1
systemctl cat bluetooth.service > "$D/machine/bluetooth-service-unit.txt" 2>&1
systemctl list-timers --all --no-pager > "$D/machine/timers.txt"
grep -n "BTUSB_AUTOSUSPEND\|HCIBTUSB" /boot/config-7.0.0-42-generic > "$D/machine/btusb-kconfig-42.txt"
cp -p /root/exp/qca9377-bt-hang/evidence/trials/results.tsv "$D/machine/results.tsv"
ls -la /run/bt-trial/ > "$D/machine/run-bt-trial.txt" 2>&1
cat /run/bt-trial/current >> "$D/machine/run-bt-trial.txt" 2>&1

cd "$D" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
du -sh "$D"
echo done
