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
    /usr/local/sbin/bt-dyndbg
    /usr/local/sbin/bt-usbmon
    /etc/systemd/system/bt-dyndbg.service
    /etc/systemd/system/bt-usbmon.service
    /etc/systemd/system/bluetooth.service.d/10-debug.conf
    /etc/systemd/journald.conf.d/10-bt-investigation.conf
    /usr/local/sbin/bt-hang-watchdog
    /usr/local/sbin/bt-health-snapshot
    /usr/local/bin/bt-health-report
    /usr/local/bin/bt-mark
    /usr/local/bin/bt-evidence
    /usr/local/bin/bt-incident
    /usr/local/bin/bt-postmortem
    /usr/local/bin/bt-status
    /usr/local/bin/bt-verify-install
    /usr/local/bin/bt-verify-kernel-mechanism
    /usr/local/bin/bt-trial
    /usr/local/bin/bt-actions
    /usr/local/bin/bt-boot-stats
    /usr/local/bin/bt-exhibit
    /usr/local/bin/bt-context
    /usr/local/bin/bt-logvolume
    /usr/local/bin/bt-phase
    /usr/local/bin/bt-env-history
    /usr/local/bin/bt-mode
    /usr/local/share/qca9377-bt-hang/mode
    /usr/local/bin/bt-interval
    /usr/local/bin/bt-stage2
    /usr/local/bin/bt-boot-provenance
    /usr/local/bin/lib/timestamp.awk
    /usr/local/bin/lib/interval.awk
    /usr/local/bin/lib/capdiff-match.awk
    /usr/local/bin/lib/trial-summary.awk
    /usr/local/bin/lib/trial-sco-table.awk
    /usr/local/bin/lib/stage2.awk
    /usr/local/bin/lib/phase.awk
    /usr/local/bin/lib/journal.sh
    /usr/local/bin/bt-sco
    /usr/local/bin/bt-capdiff
    /usr/local/sbin/bt-capture
    /etc/systemd/system/bt-capture.service
    /etc/systemd/system/bt-trial-auto.service
    /usr/local/bin/bt-sanitize-logs
    /usr/local/share/qca9377-bt-hang/installed-at
    /usr/local/bin/bt-boot-list
    /usr/local/bin/bt-state
    /usr/local/bin/bt-boots
    /usr/local/bin/bt-diagnose
    /usr/local/bin/bt-timeline
    /usr/local/sbin/bt-trace
    /etc/systemd/system/bt-trace.service
    /etc/udev/rules.d/51-bluetooth-health-snapshot.rules
    /usr/local/share/qca9377-bt-hang/baseline.tsv
    /etc/systemd/system/bt-hang-watchdog.service
    /etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf
    /etc/systemd/system/bt-hang-watchdog.service.d/20-verbose.conf
    /etc/systemd/system/bt-health-snapshot.service.d/10-device.conf
    /etc/systemd/system/bt-health-snapshot.service
    /etc/systemd/system/bt-health-snapshot-event.service
    /etc/systemd/system/bt-health-snapshot.timer
    /etc/modprobe.d/btusb-qca9377.conf
    /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules
)

# Directories to remove only if empty after the files above are gone.
DIRS=(
    /usr/local/bin/lib
    /etc/systemd/system/bluetooth.service.d
    /etc/systemd/journald.conf.d
    /etc/systemd/system/bt-hang-watchdog.service.d
    /etc/systemd/system/bt-health-snapshot.service.d
    /usr/local/share/qca9377-bt-hang
)

UNITS=(
    bt-hang-watchdog.service
    bt-health-snapshot.timer
    bt-trace.service
    bt-dyndbg.service
    bt-usbmon.service
    bt-capture.service
    bt-trial-auto.service
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
        # rmdir --ignore-fail-on-non-empty is silent when it declines, which is
        # how leftovers hide. A systemctl-edit override.conf, or a drop-in this
        # script does not know about, would otherwise survive an "uninstall"
        # that reported success.
        if [[ -d "$d" ]]; then
            echo "  ! $d still contains files not installed by this project:"
            ls -A "$d" 2>/dev/null | sed 's/^/      /'
            echo "      remove manually if you want a completely clean revert"
        fi
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
# Drops the raised journal size cap and the bluetoothd -d override. Existing
# journal files are kept; systemd will simply trim to the default cap over time.
run systemctl restart systemd-journald
echo

echo "[5/5] restore btusb default (enable_autosuspend=Y)"
# Counted, not `grep -q`: under pipefail the pipeline exits non-zero exactly
# when the module IS loaded, so the restore would be skipped precisely when it
# is needed. lsmod's output is short enough that it usually finishes writing
# first — which makes the failure intermittent rather than absent.
n_btusb=$(lsmod | grep -c "^btusb" || true)
if (( ${n_btusb:-0} > 0 )); then
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
