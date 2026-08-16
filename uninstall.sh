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
FAILED=0
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

# These lists are hand-written, and that is ACCEPTED here rather than fixed:
# tests/run-tests derives the installed set from install.sh and asserts every
# install_file destination appears below, and tools/verify-restored.sh
# re-derives it at run time — three overlapping checks that fail differently
# (review 2026-08-15T1752Z §2.6). Do not add a fourth list; extend install.sh
# and let the invariant fail until this file catches up.
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
    /usr/local/bin/bt-trial-audit
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
    /usr/local/bin/bt-window
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

# ── BT_DESTDIR — the same staging prefix install.sh takes ────────────────
#
# The pair has to be tested as a pair. "Uninstalling is a complete
# restoration" is a claim about what install.sh CREATES and uninstall.sh
# REMOVES, and neither script can be read to establish it — this repository
# has already shipped the two out of step, with four artifacts installed and
# never removed while the summary printed "complete restoration".
#
# Applied to the arrays rather than at each use site, so a path added to
# FILES or DIRS tomorrow is covered without anyone remembering to prefix it.
# Empty by default: a real uninstall is unchanged.
DESTDIR="${BT_DESTDIR:-}"
if [[ -n "$DESTDIR" ]]; then
    echo "!! BT_DESTDIR=$DESTDIR — staging uninstall; the SYSTEM WILL NOT BE TOUCHED."
    echo "   Files go under the prefix; systemctl, udevadm and the btusb reload"
    echo "   are skipped and printed instead of run."
    echo
    for i in "${!FILES[@]}"; do FILES[i]="$DESTDIR${FILES[i]}"; done
    for i in "${!DIRS[@]}";  do DIRS[i]="$DESTDIR${DIRS[i]}";  done
fi

run() {
    # STAGING MUST GATE THE COMMANDS, NOT ONLY THE PATHS.
    #
    # BT_DESTDIR prefixes every file path, and the banner above promises the
    # system will not be touched. That promise was FALSE. `systemctl enable
    # --now bt-hang-watchdog`, `udevadm control --reload-rules` and the btusb
    # reload take no path argument, so a prefix could never reach them: a
    # staging --apply re-armed the watchdog and the probe timer against the
    # live machine, and `modprobe -r btusb` reset the controller — while the
    # operator read that nothing was touched. On the investigation machine
    # that destroys experiment mode and whatever window is open.
    #
    # THE SUITE COULD NOT SEE IT. Its staging helper puts stubs for
    # systemctl/udevadm/modprobe on PATH and verifies the stub wins, so the
    # commands were harmless THERE. The guard was in the test, not in the
    # tool — it protected every run except a human's. Same shape as the escape
    # that closed a live trial: a control that holds where it is developed and
    # not where it is used. Found by the maintainer, on the machine.
    #
    # DENY BY DEFAULT. The allowlist is the file-mutating commands this script
    # actually hands to run() — rm and rmdir — and nothing else. A
    # command added tomorrow is skipped in staging, so the staged round trip
    # fails loudly; the alternative failure direction is a system command
    # executing silently, and only one of those is recoverable.
    if (( APPLY )) && [[ -n "$DESTDIR" ]]; then
        case "${1:-}" in
            install|rm|rmdir|mkdir) ;;
            *) echo "  staging: NOT executed (system command): $*"; return 0 ;;
        esac
    fi
    if (( APPLY )); then
        echo "  + $*"
        if ! "$@"; then
            # Accumulate rather than abort: later removals are independent of
            # an earlier failure, and a partial revert should still remove
            # everything it can. But the summary must then tell the truth —
            # install.sh gained exactly this accumulator in the Phase-5 review
            # and the uninstaller never did, so "UNINSTALL COMPLETE" printed
            # over failed systemctl calls and unremovable files
            # (review 2026-08-15T1752Z §2.6).
            echo "    ERROR: command failed: $*" >&2
            FAILED=1
            return 1
        fi
    else echo "  would run: $*"; fi
}

if (( APPLY )); then
    echo "=== UNINSTALL (applying) ==="
    # A staging root needs no privilege; the system one does.
    [[ $EUID -eq 0 || -n "$DESTDIR" ]] || { echo "must run as root" >&2; exit 1; }
else
    echo "=== UNINSTALL (DRY RUN — nothing will be changed) ==="
    echo "    re-run with --apply to actually revert"
fi
(( PURGE_METRICS )) && echo "    --purge-metrics: /var/log/bt-health will also be removed"
echo

echo "[1/5] stop and disable added systemd units"
for u in "${UNITS[@]}"; do
    if [[ -e "$DESTDIR/etc/systemd/system/$u" ]]; then
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
if [[ -e "$DESTDIR/var/log/bt-health" ]]; then
    if (( PURGE_METRICS )); then
        run rm -rf "$DESTDIR/var/log/bt-health"
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
    # Seamed for the same reason every other kernel-state read here is: the
    # two branches below differ by whether the module is IN USE, and that is
    # not a state a test may create on a real machine — forcing a usecount
    # means holding the controller open, which is the one thing this project's
    # tests must never do to the device under investigation.
    uc=$(awk '/^btusb/ {print $3}' "${BT_PROC_MODULES:-/proc/modules}")
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
    if (( FAILED )); then
        echo "=== UNINSTALL INCOMPLETE ===" >&2
        echo "One or more steps failed (see ERROR lines above). Everything that" >&2
        echo "could be removed was removed; what failed is still in place." >&2
        echo "Run ./tools/verify-restored.sh for the authoritative leftover list," >&2
        echo "fix the cause, and re-run — this script is idempotent." >&2
        exit 1
    fi
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
