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


# ── EXPERIMENT MODE GUARD ─────────────────────────────────────────────────
# install.sh reinstalls the workarounds — modprobe override, udev pin, watchdog,
# probe timer. If the machine is deliberately in experiment mode, that silently
# reverts the baseline the current measurements depend on, and the reversion is
# invisible unless someone runs `bt-mode status` afterwards. It happened once.
MODE_STAMP=/usr/local/share/qca9377-bt-hang/mode
if [[ -r "$MODE_STAMP" ]] && grep -q '^experiment' "$MODE_STAMP" 2>/dev/null; then
    echo "!! This machine is in EXPERIMENT mode ($(cat "$MODE_STAMP"))."
    echo "   Installing would re-enable the watchdog, the probe timer, the"
    echo "   modprobe autosuspend override and the udev power pin — reverting"
    echo "   the controlled baseline without saying so."
    echo
    if [[ "${BT_FORCE_INSTALL:-0}" != 1 ]]; then
        echo "   Refusing. To update tooling while staying in experiment mode:"
        echo "       sudo BT_FORCE_INSTALL=1 ./install.sh --apply && sudo bt-mode experiment"
        echo "   Or leave experiment mode first:  sudo bt-mode mitigation"
        exit 3
    fi
    echo "   BT_FORCE_INSTALL=1 — continuing. Re-apply the mode afterwards:"
    echo "       sudo bt-mode experiment"
    echo
    # THE INSTALLER IS NOT PASSIVE, EVEN WHEN WHAT IT INSTALLS IS.
    #
    # The guard above asks "will this change the treatment?" and the force flag
    # answers "no, these are read-only tools". Both can be true while the
    # install itself still resets the device: it reloads btusb.
    #
    # On 2026-08-13 that ended a live observation. The controller had been in
    # stage 1 — HCI dead, USB healthy — for 72 minutes with no intervention,
    # the first such window in the project, and the only USB-layer line in the
    # whole of it was this script's `deregistering interface driver btusb`.
    # Everything after was recovery noise from our own action (EX-016).
    #
    # A dead controller cannot be made worse, so this warns rather than
    # refuses; the operator has to be the one who decides the window is over.
    #
    # Counted, not `grep -q` — see the note at the btusb reload below.
    n_tmo_warn=$(journalctl -k -b 0 --no-pager 2>/dev/null \
                 | grep -cE 'command( 0x[0-9a-f]+)? tx timeout' || true)
    if (( ${n_tmo_warn:-0} > 0 )); then
        echo "!! THIS BOOT HAS ALREADY LOGGED AN HCI COMMAND TIMEOUT."
        echo "   Installing reloads btusb, which resets the controller and ENDS"
        echo "   any stage-1 observation currently in progress. If you are"
        echo "   timing how long the controller survives on the USB bus after"
        echo "   it stopped answering HCI, that measurement stops here and"
        echo "   becomes right-censored."
        echo
        echo "   Record it first:   bt-exhibit new ... --cmd '...'"
        echo "   Continuing in 10 s — Ctrl-C to stop."
        sleep 10
        echo
    fi
fi

# ── OPEN-TRIAL GUARD — EVERY APPLY, NOT ONLY EXPERIMENT MODE ─────────────
# The first version of this guard lived inside the experiment-mode branch
# above, so in mitigation mode — the default, and the mode in which
# bt-trial-auto opens a trial on EVERY boot — an install reloaded btusb
# mid-trial with no warning at all. The trial's own interior-perturbation scan
# catches it after the fact (the row becomes PERTURBED: and pools with
# nothing), but a contaminated trial detected at close is still a trial lost.
# On 2026-08-13 exactly this contaminated trial stock #2.
if (( APPLY )) && [[ -e "${BT_STATE:-/run/bt-trial}/current" ]]; then
    echo "!! A TRIAL IS OPEN ($(grep -m1 '^build=' "${BT_STATE:-/run/bt-trial}/current" 2>/dev/null))."
    echo "   Installing reloads btusb. That is an intervention this trial's"
    echo "   treatment column does not record, and it makes the trial"
    echo "   non-comparable with the rest of the series."
    echo
    echo "   Close it first:    bt-trial ok    (or: bt-trial abort)"
    echo "   Or record it:      bt-trial step \"install.sh reloaded btusb\""
    echo "   Continuing in 10 s — Ctrl-C to stop."
    sleep 10
    echo
fi

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
    echo "           reboot) is needed. A warm reboot is BELIEVED not to recover"
    echo "           it, but that has never been tested — see EX-017 and EX-019."
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
install_file "$SRC/tools/bt-verify-install" /usr/local/bin/bt-verify-install 0755
install_file "$SRC/tools/bt-verify-kernel-mechanism" /usr/local/bin/bt-verify-kernel-mechanism 0755
install_file "$SRC/tools/bt-trial"       /usr/local/bin/bt-trial       0755
install_file "$SRC/tools/bt-actions"     /usr/local/bin/bt-actions     0755
install_file "$SRC/tools/bt-boot-stats"  /usr/local/bin/bt-boot-stats  0755
install_file "$SRC/tools/bt-exhibit"     /usr/local/bin/bt-exhibit     0755
install_file "$SRC/tools/bt-context"     /usr/local/bin/bt-context     0755
install_file "$SRC/tools/bt-logvolume"   /usr/local/bin/bt-logvolume   0755
install_file "$SRC/tools/bt-phase"       /usr/local/bin/bt-phase       0755
install_file "$SRC/tools/bt-env-history" /usr/local/bin/bt-env-history 0755
install_file "$SRC/tools/bt-mode"        /usr/local/bin/bt-mode        0755
install_file "$SRC/tools/bt-interval"    /usr/local/bin/bt-interval    0755
install_file "$SRC/tools/bt-stage2"      /usr/local/bin/bt-stage2      0755
install_file "$SRC/tools/bt-boot-provenance" /usr/local/bin/bt-boot-provenance 0755
# Shared awk programs. These are loaded with `awk -f`, so they must sit where
# the tools look: <dir of the tool>/lib.
install_file "$SRC/tools/lib/timestamp.awk"     /usr/local/bin/lib/timestamp.awk     0644
install_file "$SRC/tools/lib/interval.awk"      /usr/local/bin/lib/interval.awk      0644
install_file "$SRC/tools/lib/capdiff-match.awk" /usr/local/bin/lib/capdiff-match.awk 0644
install_file "$SRC/tools/lib/trial-summary.awk"   /usr/local/bin/lib/trial-summary.awk   0644
install_file "$SRC/tools/lib/trial-sco-table.awk" /usr/local/bin/lib/trial-sco-table.awk 0644
install_file "$SRC/tools/lib/stage2.awk"        /usr/local/bin/lib/stage2.awk        0644
if command -v btmon >/dev/null 2>&1; then
    install_file "$SRC/bin/bt-trace"            /usr/local/sbin/bt-trace                    0755
    install_file "$SRC/systemd/bt-trace.service" /etc/systemd/system/bt-trace.service       0644
    install_file "$SRC/tools/bt-sco"            /usr/local/bin/bt-sco                       0755
    install_file "$SRC/tools/bt-capdiff"        /usr/local/bin/bt-capdiff                   0755
    TRACE=1
else
    echo "  WARNING: btmon not found (package: bluez) — btmon-based capture not installed"
    TRACE=0
fi

# Decode-free capture. Independent of btmon, and specifically of btmon crashing:
# 67 aborts in one boot lost the SCO parameters this investigation now needs.
install_file "$SRC/bin/bt-capture"             /usr/local/sbin/bt-capture             0755
install_file "$SRC/systemd/bt-capture.service" /etc/systemd/system/bt-capture.service 0644

# Every boot is a trial. Opened before bluetooth.service so it covers the boot
# from before the first HCI command, closed by the watchdog on a hang or by
# systemd at shutdown.
install_file "$SRC/systemd/bt-trial-auto.service" /etc/systemd/system/bt-trial-auto.service 0644

# Kernel dynamic debug: the driver's own account of its decisions. Must be
# enabled before bluetooth.service opens the adapter, hence a sysinit oneshot.
install_file "$SRC/bin/bt-dyndbg"                 /usr/local/sbin/bt-dyndbg              0755
install_file "$SRC/systemd/bt-dyndbg.service"     /etc/systemd/system/bt-dyndbg.service  0644

# bluetoothd debug: the layer recording what the operator actually did.
install_file "$SRC/etc/systemd/bluetooth.service.d/10-debug.conf" \
             /etc/systemd/system/bluetooth.service.d/10-debug.conf 0644

# Journal size cap: verbose logging is only useful if it survives to be read.
install_file "$SRC/etc/systemd/journald.conf.d/10-bt-investigation.conf" \
             /etc/systemd/journald.conf.d/10-bt-investigation.conf 0644

# USB transport capture: the one layer with no record during stage 2.
if command -v tcpdump >/dev/null 2>&1; then
    install_file "$SRC/bin/bt-usbmon"             /usr/local/sbin/bt-usbmon              0755
    install_file "$SRC/systemd/bt-usbmon.service" /etc/systemd/system/bt-usbmon.service  0644
    USBMON=1
else
    echo "  WARNING: tcpdump not found — USB transport capture not installed"
    USBMON=0
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
    # Same script, separate unit name, so the journal records WHY each probe
    # exists. udev fires this one; the timer fires the other. Without that
    # distinction the two are indistinguishable and an exposure analysis
    # silently mixes outcome-dependent timestamps into its baseline (EX-012).
    install_file "$SRC/systemd/bt-health-snapshot-event.service" \
                 /etc/systemd/system/bt-health-snapshot-event.service 0644
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
run systemctl enable --now bt-capture
run systemctl enable --now bt-trial-auto
run systemctl enable --now bt-dyndbg
(( USBMON ))  && run systemctl enable --now bt-usbmon
# Picks up the raised journal size cap. Restarting journald is safe: clients
# reconnect to the socket, and nothing already written is lost.
run systemctl restart systemd-journald
# Applies the bluetoothd -d override. Deliberately NOT restarted here when the
# controller is mid-failure: restarting bluetoothd against a wedged controller
# adds a burst of timing-out commands to the log for no benefit. It will pick
# the override up on the next boot regardless.
run systemctl daemon-reload

# Apply the autosuspend setting immediately when it is safe to do so.
#
# THE ORIGINAL GUARD ASKED THE WRONG QUESTION, AND ITS ANSWER WAS INVERTED.
#
# "Is btusb in use?" was meant to protect live audio connections: usecount 0
# means nothing is connected, so a reload drops nothing. But a controller that
# has stopped answering HCI has no connections *because it is wedged*. Its
# usecount is 0. The guard therefore read the one state in which a reload is
# most destructive as the state in which it is safest.
#
# On 2026-08-13 that ended the first uncensored stage-1 observation in this
# project: the controller had been HCI-dead but USB-healthy for 72 minutes with
# no intervention of any kind, and the only USB-layer line in the whole window
# is this block's `modprobe -r btusb`. Everything after it — descriptor read
# errors, `device not accepting address`, `USB disconnect` — was our own
# recovery noise, and whether the device would ever have left the bus on its
# own is now an open question (EX-016).
#
# So the guard now asks both questions: is anything connected, AND has the
# controller already failed this boot? The second is the one that mattered.
if (( APPLY )); then
    uc=$(awk '/^btusb/ {print $3}' /proc/modules 2>/dev/null)
    # COUNTED, NOT `grep -q`, AND THIS IS THE SITE WHERE IT MATTERS MOST.
    #
    # Under `set -o pipefail` a `producer | grep -q` pipeline exits NON-ZERO
    # exactly when the pattern is found: grep leaves at the first match,
    # journalctl dies of SIGPIPE, pipefail propagates it. `&& failed_this_boot=1`
    # would then fire only when there was NO timeout — and the journal this
    # scans is millions of lines, which is precisely the size at which the
    # producer is still writing when grep exits.
    #
    # So this guard, whose entire purpose is to stop a btusb reload from
    # destroying a stage-1 observation, would have reported `safe to reload` in
    # exactly the state it exists to protect. Six sites in tools/, bin/ and
    # devtools/ were fixed for this in 96c3c90; the invariant that found them
    # did not scan install.sh, so this one survived the sweep that was supposed
    # to be repo-wide.
    n_tmo=$(journalctl -k -b 0 --no-pager 2>/dev/null \
            | grep -cE 'command( 0x[0-9a-f]+)? tx timeout' || true)
    failed_this_boot=0
    (( ${n_tmo:-0} > 0 )) && failed_this_boot=1

    if (( failed_this_boot )); then
        echo "  btusb NOT reloaded — this boot has logged an HCI command timeout."
        echo "    A wedged controller has usecount 0, so the old 'is it in use?'"
        echo "    check would have called this safe. Reloading here resets the"
        echo "    device and destroys any stage-1 observation in progress."
        echo "    The autosuspend setting applies at the next boot."
        echo "    To reload anyway: sudo modprobe -r btusb && sudo modprobe btusb"
    elif [[ "${uc:-}" == "0" ]]; then
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
