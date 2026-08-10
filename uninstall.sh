#!/bin/bash
# uninstall.sh — remove everything install.sh added.
#
# Usage:
#   ./uninstall.sh          dry run — print what would happen, change nothing
#   ./uninstall.sh --apply  actually revert
#
# See docs/changes-applied.md for the full protocol.

set -uo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1

FILES=(
    /usr/local/sbin/bt-hang-watchdog
    /usr/local/sbin/bt-health-snapshot
    /etc/systemd/system/bt-hang-watchdog.service
    /etc/systemd/system/bt-health-snapshot.service
    /etc/systemd/system/bt-health-snapshot.timer
    /etc/modprobe.d/btusb-qca9377.conf
    /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
    /usr/local/bin/bt-health-report
)

UNITS=(
    bt-hang-watchdog.service
    bt-health-snapshot.timer
)

# Collected metrics are DATA, not configuration. Kept by default so the
# effectiveness record survives a rollback; pass --purge-metrics to remove.
PURGE_METRICS=0
[[ "${2:-}" == "--purge-metrics" || "${1:-}" == "--purge-metrics" ]] && PURGE_METRICS=1

run() {
    if (( APPLY )); then
        echo "  + $*"
        "$@"
    else
        echo "  would run: $*"
    fi
}

if (( APPLY )); then
    echo "=== UNINSTALL (applying) ==="
else
    echo "=== UNINSTALL (DRY RUN — nothing will be changed) ==="
    echo "    re-run with --apply to actually revert"
fi
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
