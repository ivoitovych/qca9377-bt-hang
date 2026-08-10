#!/bin/bash
# install.sh — install the Bluetooth hang watchdog and health metrics collector.
#
#   sudo ./install.sh            dry run — show what would happen
#   sudo ./install.sh --apply    install
#   sudo ./install.sh --apply --no-metrics    watchdog only, skip the collector
#
# Reverse with ./uninstall.sh
#
# Every file installed is NEW. Nothing pre-existing is modified, so uninstalling
# is a complete restoration.

set -uo pipefail

APPLY=0
METRICS=1
for a in "$@"; do
    case "$a" in
        --apply)       APPLY=1 ;;
        --no-metrics)  METRICS=0 ;;
        -h|--help)     sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 1 ;;
    esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Device this build targets. Override for a different controller:
#   BT_VID=0cf3 BT_PID=e300 sudo -E ./install.sh --apply
VID="${BT_VID:-13d3}"
PID="${BT_PID:-3503}"

run() {
    if (( APPLY )); then echo "  + $*"; "$@" || return 1
    else echo "  would run: $*"; fi
}

install_file() {
    local src="$1" dst="$2" mode="$3"
    if [[ -e "$dst" ]]; then
        echo "  ! $dst already exists — will be OVERWRITTEN"
    fi
    run install -D -m "$mode" "$src" "$dst"
}

if (( APPLY )); then
    echo "=== INSTALL ==="
    [[ $EUID -eq 0 ]] || { echo "must run as root" >&2; exit 1; }
else
    echo "=== INSTALL (DRY RUN — nothing will change) ==="
    echo "    re-run with --apply to install"
fi
echo "    target device: $VID:$PID"
echo

# --- sanity check ----------------------------------------------------------
echo "[1/5] preflight"
found=0
for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    if [[ "$(<"$d/idVendor")" == "$VID" && "$(<"$d/idProduct")" == "$PID" ]]; then
        echo "  device $VID:$PID present at $(basename "$d")"
        found=1; break
    fi
done
if (( ! found )); then
    echo "  WARNING: $VID:$PID not on the USB bus right now."
    echo "           If the controller is already hung, a full POWER-OFF (not a"
    echo "           reboot) is needed — a warm reset does not drop the M.2 rail."
    echo "           Installing anyway; the watchdog arms itself at boot."
fi
for c in hciconfig python3 journalctl; do
    command -v "$c" >/dev/null || echo "  WARNING: '$c' not found — required at runtime"
done
echo

# --- watchdog --------------------------------------------------------------
echo "[2/5] watchdog"
install_file "$SRC/bin/bt-hang-watchdog" /usr/local/sbin/bt-hang-watchdog 0755
install_file "$SRC/systemd/bt-hang-watchdog.service" \
             /etc/systemd/system/bt-hang-watchdog.service 0644
echo

# --- autosuspend -----------------------------------------------------------
echo "[3/5] disable USB autosuspend for the radio"
install_file "$SRC/etc/modprobe.d/btusb-qca9377.conf" \
             /etc/modprobe.d/btusb-qca9377.conf 0644
install_file "$SRC/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules" \
             /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules 0644
echo

# --- metrics ---------------------------------------------------------------
echo "[4/5] health metrics collector"
if (( METRICS )); then
    install_file "$SRC/bin/bt-health-snapshot" /usr/local/sbin/bt-health-snapshot 0755
    install_file "$SRC/systemd/bt-health-snapshot.service" \
                 /etc/systemd/system/bt-health-snapshot.service 0644
    install_file "$SRC/systemd/bt-health-snapshot.timer" \
                 /etc/systemd/system/bt-health-snapshot.timer 0644
    install_file "$SRC/tools/bt-health-report.sh" /usr/local/bin/bt-health-report 0755
    # ship the baseline where the installed report can find it
    install_file "$SRC/data/baseline.tsv" \
                 /usr/local/share/qca9377-bt-hang/baseline.tsv 0644
else
    echo "  skipped (--no-metrics)"
fi
echo

# --- activate --------------------------------------------------------------
echo "[5/5] activate"
run udevadm control --reload-rules
run systemctl daemon-reload
run systemctl enable --now bt-hang-watchdog
(( METRICS )) && run systemctl enable --now bt-health-snapshot.timer

# Apply the autosuspend setting immediately when it is safe to do so:
# reloading btusb while it is in use would drop live connections.
if (( APPLY )); then
    uc=$(awk '/^btusb/ {print $3}' /proc/modules 2>/dev/null)
    if [[ "${uc:-}" == "0" ]]; then
        run modprobe -r btusb
        run modprobe btusb
    elif [[ -n "${uc:-}" ]]; then
        echo "  btusb in use (usecount=$uc) — autosuspend setting applies at next boot"
    fi
fi
echo

if (( APPLY )); then
    echo "=== INSTALLED ==="
    echo
    echo "Verify:"
    echo "  systemctl status bt-hang-watchdog"
    echo "  cat /sys/module/btusb/parameters/enable_autosuspend    # expect N"
    echo "  cat /sys/bus/usb/devices/*/power/control               # expect on for the radio"
    echo
    echo "Watch it work:   journalctl -u bt-hang-watchdog -f"
    (( METRICS )) && echo "Effectiveness:   bt-health-report"
    echo
    echo "NOTE: the udev rule fires on device 'add', so power/control only flips"
    echo "      to 'on' after the next enumeration (i.e. after a reboot)."
else
    echo "=== DRY RUN COMPLETE — nothing changed ==="
fi
