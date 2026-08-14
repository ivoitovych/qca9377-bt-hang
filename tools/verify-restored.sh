#!/bin/bash
# verify-restored.sh — check whether this machine is back to its pre-investigation state.
#
#   ./tools/verify-restored.sh
#
# Read-only: inspects, never changes anything. Exit 0 if fully restored,
# 1 if anything from the investigation is still in place.
#
# See docs/restore-original-state.md for what each item is and how to revert it.

set -uo pipefail

# Seams, all defaulting to the real thing. This script's answer is "yes, the
# machine is back to normal" — the one claim nobody re-checks by hand, because
# checking it by hand is exactly what the script replaced. It could not be run
# anywhere except on a machine mid-investigation, so it had never been run
# under test at all.
_HERE_VR_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
[[ -r "$_HERE_VR_LIB/journal.sh" ]] || {
    echo "verify-restored.sh: missing $_HERE_VR_LIB/journal.sh" >&2; exit 1; }
# shellcheck source=tools/lib/journal.sh
source "$_HERE_VR_LIB/journal.sh"

VID="${BT_VID:-13d3}"
PID="${BT_PID:-3503}"
SYSFS_USB="${BT_SYSFS_USB:-/sys/bus/usb/devices}"
SYSFS_MOD="${BT_SYSFS_MODULE:-/sys/module/btusb/parameters}"
HEALTH_DIR="${BT_HEALTH_DIR:-/var/log/bt-health}"

pass=0; fail=0; note=0

# NOTE: (( x++ )) evaluates to the value BEFORE incrementing, so it returns
# exit status 1 when the counter is 0. Without the explicit `return 0` these
# helpers would report failure to their caller, and an idiom like
#   [[ -e $f ]] && bad "..." || ok "..."
# would run BOTH branches on the first hit. Use post-increment + return 0.
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; pass=$((pass+1)); return 0; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; fail=$((fail+1)); return 0; }
info() { printf '  \033[33m•\033[0m %s\n' "$1"; note=$((note+1)); return 0; }

echo "RESTORATION CHECK — $(date -Iseconds)"
echo "════════════════════════════════════════════════════════════"

echo
echo "1. Installed files removed"
# DERIVED from install.sh, not hand-written. The list this replaces was frozen
# at the original 11-file install and reported "matches its pre-investigation
# state" while ~30 later artifacts — the capture stack, dyndbg, the awk libs,
# the trial machinery — were still on the machine. Same derivation as
# bt-verify-install: install.sh is the single source of truth for what got
# installed, so it is also the source of truth for what "removed" means.
HERE_VR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SH=""
for c in "${BT_INSTALL_SH:-}" "$HERE_VR/../install.sh" ./install.sh /root/exp/qca9377-bt-hang/install.sh; do
    [[ -r "$c" ]] && { INSTALL_SH="$c"; break; }
done
if [[ -z "$INSTALL_SH" ]]; then
    bad "cannot find install.sh to derive the artifact list — restoration NOT verifiable"
else
    # install_file destinations, plus the generated udev rules, drop-ins and
    # stamps that install.sh writes outside install_file.
    mapfile -t VR_FILES < <(
        { awk '{ while (/\\$/ && (getline nxt) > 0) { sub(/\\$/, "", $0); $0 = $0 nxt } print }' \
              "$INSTALL_SH" \
          | grep -oE 'install_file[[:space:]]+"\$SRC/[^"]+"[[:space:]]+[^[:space:]]+' \
          | awk '{print $3}'
          printf '%s\n' \
              /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules \
              /etc/udev/rules.d/51-bluetooth-health-snapshot.rules \
              /etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf \
              /etc/systemd/system/bt-health-snapshot.service.d/10-device.conf \
              /usr/local/share/qca9377-bt-hang/installed-at \
              /usr/local/share/qca9377-bt-hang/mode
        } | sort -u)
    if (( ${#VR_FILES[@]} < 10 )); then
        bad "derived only ${#VR_FILES[@]} artifact(s) from $INSTALL_SH — refusing a false all-clear"
    else
        for f in "${VR_FILES[@]}"; do
            if [[ -e "$f" ]]; then bad "still present: $f"
            elif [[ -e "$f.disabled" ]]; then
                # bt-mode experiment moves files aside; uninstall removes only
                # the active names, so these survive the experiment->uninstall
                # path and a clean revert must catch them.
                bad "still present (moved aside by bt-mode): $f.disabled"
            else ok "removed: $f"; fi
        done
    fi
fi

echo
echo "2. Services stopped and disabled"
# Unit list derived from what install.sh enables, for the same reason.
mapfile -t VR_UNITS < <(
    { [[ -n "${INSTALL_SH:-}" ]] && grep -oE 'systemctl enable --now [a-z0-9.-]+' "$INSTALL_SH" | awk '{print $NF}'
      printf '%s\n' bt-hang-watchdog bt-health-snapshot.timer
    } | sort -u)
for u in "${VR_UNITS[@]}"; do
    st=$(systemctl is-active "$u" 2>/dev/null || true)
    en=$(systemctl is-enabled "$u" 2>/dev/null || true)
    if [[ "$st" == "active" || "$en" == "enabled" ]]; then
        bad "$u is $st/$en"
    else
        ok "$u is not running"
    fi
done

echo
echo "3. Original settings restored"
as=$(cat "$SYSFS_MOD/enable_autosuspend" 2>/dev/null || echo "-")
case "$as" in
    Y) ok  "btusb enable_autosuspend = Y (original)" ;;
    N) bad "btusb enable_autosuspend = N — still the mitigation value" ;;
    *) info "btusb not loaded — defaults apply at next load" ;;
esac

ctrl=""
for d in "$SYSFS_USB"/*; do
    [[ -f "$d/idVendor" && -f "$d/idProduct" ]] || continue
    if [[ "$(<"$d/idVendor")" == "$VID" && "$(<"$d/idProduct")" == "$PID" ]]; then
        ctrl=$(cat "$d/power/control" 2>/dev/null); break
    fi
done
case "$ctrl" in
    auto) ok   "usb power/control = auto (original)" ;;
    on)   info "usb power/control = on — clears when the device re-enumerates (reboot)" ;;
    "")   info "device $VID:$PID not on the bus — cannot check power/control" ;;
    *)    info "usb power/control = $ctrl" ;;
esac

st=$(systemctl is-active bluetooth 2>/dev/null || true)
en=$(systemctl is-enabled bluetooth 2>/dev/null || true)
if [[ "$st" == "active" && "$en" == "enabled" ]]; then
    ok "bluetooth.service is active/enabled (original)"
else
    bad "bluetooth.service is $st/$en — expected active/enabled"
fi

echo
echo "4. Untouched by design — confirming still true"
if dpkg --verify bluez >/dev/null 2>&1 && [[ -z "$(dpkg --verify bluez 2>&1)" ]]; then
    ok "dpkg --verify bluez: no packaged file modified"
else
    bad "dpkg --verify bluez reports modified files:"
    dpkg --verify bluez 2>&1 | sed 's/^/      /'
fi

echo
echo "5. Leftover data (not removed by default)"
if [[ -e "$HEALTH_DIR" ]]; then
    rows=$(( $(wc -l < "$HEALTH_DIR/metrics.tsv" 2>/dev/null || echo 1) - 1 ))
    info "$HEALTH_DIR still present ($rows metric rows) — rm -rf to clear"
else
    ok "$HEALTH_DIR removed"
fi

echo
echo "6. Synthetic log entries (cleared by reboot)"
# HCI command timeouts, opcode-named or not. NOT bare "tx timeout": that
# also matches `link tx timeout` (ACL supervision, a different layer), of
# which this machine has logged 7 against 173 real command timeouts. See
# evidence/exhibits/015-timeout-pattern-undercount.md.
tx=$(bt_journal -k -b 0 --no-pager 2>/dev/null | grep -cE "command( 0x[0-9a-f]+)? tx timeout" || true)
up=$(awk '{printf "%.1f", $1/3600}' /proc/uptime)
info "this boot shows $tx 'tx timeout' events (uptime ${up} h)"
info "  if this is still the 2026-08-10 boot, 3 of them are synthetic test lines"
info "  a reboot removes them entirely"

echo
echo "7. User-wide Claude Code setting (outside uninstall.sh)"
if grep -q '"attribution"' /root/.claude/settings.json 2>/dev/null; then
    info "~/.claude/settings.json still has the attribution block (harmless; see docs §4)"
else
    ok "~/.claude/settings.json has no attribution block"
fi

echo
echo "════════════════════════════════════════════════════════════"
printf 'restored: %d   outstanding: %d   informational: %d\n' "$pass" "$fail" "$note"
if (( fail )); then
    echo
    echo "Not fully restored. Run:  sudo ./uninstall.sh --apply"
    echo "See docs/restore-original-state.md for items uninstall.sh does not cover."
    exit 1
fi
echo
echo "System matches its pre-investigation state (see informational notes above)."
