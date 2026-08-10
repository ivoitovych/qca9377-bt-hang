#!/bin/bash
# install.sh — install the Bluetooth hang watchdog and health metrics collector.
#
#   sudo ./install.sh                          dry run — show what would happen
#   sudo ./install.sh --apply                  install
#   sudo ./install.sh --apply --no-metrics     watchdog only, skip the collector
#
# Different controller:
#   BT_VID=0cf3 BT_PID=e300 sudo -E ./install.sh --apply
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
        -h|--help)     sed -n '2,15p' "$0"; exit 0 ;;
        *) echo "unknown option: $a" >&2; exit 1 ;;
    esac
done

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Device this install targets. The defaults must match the script defaults in
# bin/bt-hang-watchdog; a drop-in is written only when they differ.
DEFAULT_VID=13d3
DEFAULT_PID=3503
VID="${BT_VID:-$DEFAULT_VID}"
PID="${BT_PID:-$DEFAULT_PID}"

FAILED=0

run() {
    if (( APPLY )); then
        echo "  + $*"
        if ! "$@"; then
            echo "    ERROR: command failed: $*" >&2
            FAILED=1
            return 1
        fi
    else
        echo "  would run: $*"
    fi
}

install_file() {
    local src="$1" dst="$2" mode="$3"
    [[ -e "$src" ]] || { echo "  ERROR: missing source file: $src" >&2; FAILED=1; return 1; }
    [[ -e "$dst" ]] && echo "  ! $dst already exists — will be OVERWRITTEN"
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

# --- preflight -------------------------------------------------------------
echo "[1/7] preflight"
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
for c in python3 journalctl; do
    command -v "$c" >/dev/null || { echo "  ERROR: '$c' is required but not found" >&2; FAILED=1; }
done
if ! command -v hciconfig >/dev/null && ! command -v btmgmt >/dev/null; then
    echo "  WARNING: neither hciconfig nor btmgmt found (package: bluez)."
    echo "           Recovery will still run, but success cannot be verified."
fi
echo

# --- watchdog --------------------------------------------------------------
echo "[2/7] watchdog"
install_file "$SRC/bin/bt-hang-watchdog" /usr/local/sbin/bt-hang-watchdog 0755
install_file "$SRC/systemd/bt-hang-watchdog.service" \
             /etc/systemd/system/bt-hang-watchdog.service 0644
echo

# --- device override -------------------------------------------------------
echo "[3/7] device selection"
DROPIN=/etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf
SNAP_DROPIN=/etc/systemd/system/bt-health-snapshot.service.d/10-device.conf
if [[ "$VID" != "$DEFAULT_VID" || "$PID" != "$DEFAULT_PID" ]]; then
    echo "  non-default device — writing $DROPIN"
    if (( APPLY )); then
        mkdir -p "$(dirname "$DROPIN")" && \
        printf '[Service]\nEnvironment=BT_VID=%s\nEnvironment=BT_PID=%s\n' "$VID" "$PID" > "$DROPIN" \
            || { echo "    ERROR: could not write $DROPIN" >&2; FAILED=1; }
        echo "  + wrote $DROPIN"
        # The metrics collector must watch the same device, or its columns
        # describe hardware the watchdog is not managing.
        if (( METRICS )); then
            mkdir -p "$(dirname "$SNAP_DROPIN")" && \
            printf '[Service]\nEnvironment=BT_VID=%s\nEnvironment=BT_PID=%s\n' "$VID" "$PID" > "$SNAP_DROPIN" \
                || { echo "    ERROR: could not write $SNAP_DROPIN" >&2; FAILED=1; }
            echo "  + wrote $SNAP_DROPIN"
        fi
    else
        echo "  would write: $DROPIN (BT_VID=$VID BT_PID=$PID)"
        (( METRICS )) && echo "  would write: $SNAP_DROPIN (BT_VID=$VID BT_PID=$PID)"
    fi
else
    echo "  default device $VID:$PID — no drop-in needed"
fi
echo

# --- autosuspend -----------------------------------------------------------
echo "[4/7] disable USB autosuspend for the radio"
install_file "$SRC/etc/modprobe.d/btusb-qca9377.conf" \
             /etc/modprobe.d/btusb-qca9377.conf 0644
# The udev rule matches on idVendor/idProduct, so it must be generated for the
# device actually being targeted rather than copied verbatim.
UDEV=/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
if (( APPLY )); then
    if sed -e "s/idVendor}==\"$DEFAULT_VID\"/idVendor}==\"$VID\"/" \
           -e "s/idProduct}==\"$DEFAULT_PID\"/idProduct}==\"$PID\"/" \
           "$SRC/etc/udev/rules.d/50-bluetooth-no-autosuspend.rules" > "$UDEV"; then
        chmod 0644 "$UDEV"
        echo "  + wrote $UDEV (for $VID:$PID)"
    else
        echo "    ERROR: could not write $UDEV" >&2; FAILED=1
    fi
else
    echo "  would write: $UDEV (for $VID:$PID)"
fi
echo

# --- observability ---------------------------------------------------------
echo "[5/7] tracing and observability"
install_file "$SRC/bin/bt-mark"          /usr/local/bin/bt-mark        0755
install_file "$SRC/bin/bt-evidence"      /usr/local/bin/bt-evidence    0755
install_file "$SRC/tools/sanitize-logs.sh" /usr/local/bin/bt-sanitize-logs 0755
install_file "$SRC/tools/bt-boot-list"   /usr/local/bin/bt-boot-list   0755
install_file "$SRC/tools/bt-state"       /usr/local/bin/bt-state       0755
install_file "$SRC/tools/bt-boots"       /usr/local/bin/bt-boots       0755
install_file "$SRC/tools/bt-diagnose"    /usr/local/bin/bt-diagnose    0755
install_file "$SRC/tools/bt-timeline.sh" /usr/local/bin/bt-timeline    0755
install_file "$SRC/tools/bt-incident"    /usr/local/bin/bt-incident    0755
install_file "$SRC/tools/bt-postmortem"  /usr/local/bin/bt-postmortem  0755
install_file "$SRC/tools/bt-status"      /usr/local/bin/bt-status      0755
if command -v btmon >/dev/null 2>&1; then
    install_file "$SRC/bin/bt-trace"            /usr/local/sbin/bt-trace                    0755
    install_file "$SRC/systemd/bt-trace.service" /etc/systemd/system/bt-trace.service       0644
    TRACE=1
else
    echo "  WARNING: btmon not found (package: bluez) — HCI capture not installed"
    TRACE=0
fi
# Event-driven snapshots: a stall unfolds faster than the 15-minute timer.
if (( METRICS )); then
    UDEV_SNAP=/etc/udev/rules.d/51-bluetooth-health-snapshot.rules
    if (( APPLY )); then
        if sed -e "s/idVendor}==\"$DEFAULT_VID\"/idVendor}==\"$VID\"/" \
               -e "s/idProduct}==\"$DEFAULT_PID\"/idProduct}==\"$PID\"/" \
               -e "s|$DEFAULT_VID/$DEFAULT_PID\*|$VID/$PID*|" \
               "$SRC/etc/udev/rules.d/51-bluetooth-health-snapshot.rules" > "$UDEV_SNAP"; then
            chmod 0644 "$UDEV_SNAP"; echo "  + wrote $UDEV_SNAP"
        else
            echo "    ERROR: could not write $UDEV_SNAP" >&2; FAILED=1
        fi
    else
        echo "  would write: $UDEV_SNAP"
    fi
fi
echo

# --- metrics ---------------------------------------------------------------
echo "[6/7] health metrics collector"
if (( METRICS )); then
    install_file "$SRC/bin/bt-health-snapshot" /usr/local/sbin/bt-health-snapshot 0755
    install_file "$SRC/systemd/bt-health-snapshot.service" \
                 /etc/systemd/system/bt-health-snapshot.service 0644
    install_file "$SRC/systemd/bt-health-snapshot.timer" \
                 /etc/systemd/system/bt-health-snapshot.timer 0644
    install_file "$SRC/tools/bt-health-report.sh" /usr/local/bin/bt-health-report 0755
    install_file "$SRC/evidence/baseline/baseline.tsv" \
                 /usr/local/share/qca9377-bt-hang/baseline.tsv 0644
else
    echo "  skipped (--no-metrics)"
fi
echo

# --- first-install stamp ---------------------------------------------------
# bt-health-report needs the moment the mitigation FIRST went in, to split boots
# into before/after. Deriving it from a unit file's mtime is wrong: every
# reinstall or edit moves it forward, so already-mitigated boots get relabelled
# "before" and contaminate the comparison. Write it once and never touch it again.
STAMP=/usr/local/share/qca9377-bt-hang/installed-at
if (( APPLY )); then
    if [[ -s "$STAMP" ]]; then
        echo "  first-install stamp preserved: $(cat "$STAMP")"
    else
        mkdir -p "$(dirname "$STAMP")" && date +%s > "$STAMP" \
            && echo "  + wrote first-install stamp $STAMP ($(cat "$STAMP"))" \
            || { echo "    ERROR: could not write $STAMP" >&2; FAILED=1; }
    fi
else
    [[ -s "$STAMP" ]] && echo "  would keep existing stamp: $(cat "$STAMP")" \
                      || echo "  would write first-install stamp: $STAMP"
fi
echo

# --- activate --------------------------------------------------------------
echo "[7/7] activate"
run udevadm control --reload-rules
run systemctl daemon-reload
run systemctl enable --now bt-hang-watchdog
(( METRICS )) && run systemctl enable --now bt-health-snapshot.timer
(( TRACE ))   && run systemctl enable --now bt-trace

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

if (( ! APPLY )); then
    echo "=== DRY RUN COMPLETE — nothing changed ==="
    exit 0
fi

if (( FAILED )); then
    echo "=== INSTALL FAILED ===" >&2
    echo "One or more steps did not complete (see ERROR lines above)." >&2
    echo "The mitigation is NOT fully active. Fix the cause and re-run," >&2
    echo "or run ./uninstall.sh --apply to clean up." >&2
    exit 1
fi

echo "=== INSTALLED ==="
echo
echo "Verify:"
echo "  systemctl status bt-hang-watchdog"
echo "  cat /sys/module/btusb/parameters/enable_autosuspend    # expect N"
echo "  cat /sys/bus/usb/devices/*/power/control               # expect on for the radio"
echo
echo "Watch it work:   journalctl -u bt-hang-watchdog -f"
echo "Timeline:        bt-timeline"
echo "Annotate a test: bt-mark \"connecting headset\""
echo "Record a session: bt-evidence start <slug> ... bt-evidence stop"
(( TRACE )) && echo "HCI captures:    /var/log/bt-health/trace/ (btmon -r <file>)"
(( METRICS )) && echo "Effectiveness:   bt-health-report"
echo
echo "NOTE: the udev rule fires on device 'add', so power/control only flips"
echo "      to 'on' after the next enumeration (i.e. after a reboot)."
