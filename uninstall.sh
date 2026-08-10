#!/bin/bash
# uninstall.sh — remove everything install.sh added.
#
#   ./uninstall.sh                          dry run — print what would happen
#   ./uninstall.sh --apply                  actually revert
#   ./uninstall.sh --apply --purge-metrics  also delete collected metrics
#
# See docs/changes-applied.md for the full protocol.

set -uo pipefail

APPLY=0
PURGE_METRICS=0
for a in "$@"; do
    case "$a" in
        --apply)          APPLY=1 ;;
        --purge-metrics)  PURGE_METRICS=1 ;;
        -h|--help)        sed -n '2,9p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2
           echo "usage: $0 [--apply] [--purge-metrics]" >&2
           exit 1 ;;
    esac
done

FILES=(
    /usr/local/sbin/bt-hang-watchdog
    /usr/local/sbin/bt-health-snapshot
    /usr/local/bin/bt-health-report
    /usr/local/bin/bt-mark
    /usr/local/bin/bt-timeline
    /usr/local/sbin/bt-trace
    /etc/systemd/system/bt-trace.service
    /etc/udev/rules.d/51-bluetooth-health-snapshot.rules
    /usr/local/share/qca9377-bt-hang/baseline.tsv
    /etc/systemd/system/bt-hang-watchdog.service
    /etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf
    /etc/systemd/system/bt-health-snapshot.service.d/10-device.conf
    /etc/systemd/system/bt-health-snapshot.service
    /etc/systemd/system/bt-health-snapshot.timer
    /etc/modprobe.d/btusb-qca9377.conf
    /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
)

# Directories to remove only if empty after the files above are gone.
DIRS=(
    /etc/systemd/system/bt-hang-watchdog.service.d
    /etc/systemd/system/bt-health-snapshot.service.d
    /usr/local/share/qca9377-bt-hang
)

UNITS=(
    bt-hang-watchdog.service
    bt-health-snapshot.timer
    bt-trace.service
)

run() {
    if (( APPLY )); then echo "  + $*"; "$@"
    else echo "  would run: $*"; fi
}

if (( APPLY )); then
    echo "=== UNINSTALL (applying) ==="
    [[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
else
    echo "=== UNINSTALL (DRY RUN — nothing will be changed) ==="
    echo "    re-run with --apply to actually revert"
fi
(( PURGE_METRICS )) && echo "    --purge-metrics: /var/log/bt-health will also be removed"
echo

echo "[1/5] stop and disable added systemd units"
for u in "${UNITS[@]}"; do
    if [[ -e "/etc/systemd/system/$u" ]]; then
        run systemctl disable --now "$u"
    else
        echo "  (not present, skipping: $u)"
    fi
done
echo

echo "[2/5] remove installed files"
for f in "${FILES[@]}"; do
    if [[ -e "$f" ]]; then
        run rm -f "$f"
    else
        echo "  (absent, nothing to do: $f)"
    fi
done
for d in "${DIRS[@]}"; do
    if [[ -d "$d" ]]; then
        run rmdir --ignore-fail-on-non-empty "$d"
    fi
done
echo

echo "[3/5] collected metrics"
if [[ -e /var/log/bt-health ]]; then
    if (( PURGE_METRICS )); then
        run rm -rf /var/log/bt-health
    else
        echo "  KEEPING /var/log/bt-health (data, not config)"
        echo "  pass --purge-metrics to delete it as well"
    fi
else
    echo "  (absent, nothing to do)"
fi
echo

echo "[4/5] reload daemons"
run systemctl daemon-reload
run udevadm control --reload-rules
echo

echo "[5/5] restore btusb default (enable_autosuspend=Y)"
if lsmod | grep -q "^btusb"; then
    uc=$(awk '/^btusb/ {print $3}' /proc/modules)
    if [[ "${uc:-0}" == "0" ]]; then
        run modprobe -r btusb
        run modprobe btusb
    else
        echo "  btusb is in use (usecount=$uc) — will revert on next reboot"
    fi
else
    echo "  btusb not loaded — will pick up defaults on next load"
fi
echo

if (( APPLY )); then
    echo "=== UNINSTALL COMPLETE ==="
    echo
    echo "Verify:"
    echo "  cat /sys/module/btusb/parameters/enable_autosuspend   # expect Y"
    echo "  systemctl status bt-hang-watchdog                     # expect: not found"
    echo
    echo "No pre-existing file was ever modified, so nothing needs restoring"
    echo "from backup. Uninstall is a complete restoration."
else
    echo "=== DRY RUN COMPLETE — no changes made ==="
fi
