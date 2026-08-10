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

VID="${BT_VID:-13d3}"
PID="${BT_PID:-3503}"

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
for f in /usr/local/sbin/bt-hang-watchdog \
         /usr/local/sbin/bt-health-snapshot \
         /usr/local/bin/bt-health-report \
         /usr/local/share/qca9377-bt-hang/baseline.tsv \
         /etc/systemd/system/bt-hang-watchdog.service \
         /etc/systemd/system/bt-hang-watchdog.service.d/10-device.conf \
         /etc/systemd/system/bt-health-snapshot.service \
         /etc/systemd/system/bt-health-snapshot.service.d/10-device.conf \
         /etc/systemd/system/bt-health-snapshot.timer \
         /etc/modprobe.d/btusb-qca9377.conf \
         /etc/udev/rules.d/50-bluetooth-no-autosuspend.rules; do
    if [[ -e "$f" ]]; then bad "still present: $f"; else ok "removed: $f"; fi
done

echo
echo "2. Services stopped and disabled"
for u in bt-hang-watchdog.service bt-health-snapshot.timer; do
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
as=$(cat /sys/module/btusb/parameters/enable_autosuspend 2>/dev/null || echo "-")
case "$as" in
    Y) ok  "btusb enable_autosuspend = Y (original)" ;;
    N) bad "btusb enable_autosuspend = N — still the mitigation value" ;;
    *) info "btusb not loaded — defaults apply at next load" ;;
esac

ctrl=""
for d in /sys/bus/usb/devices/*; do
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
if [[ -e /var/log/bt-health ]]; then
    rows=$(( $(wc -l < /var/log/bt-health/metrics.tsv 2>/dev/null || echo 1) - 1 ))
    info "/var/log/bt-health still present ($rows metric rows) — rm -rf to clear"
else
    ok "/var/log/bt-health removed"
fi

echo
echo "6. Synthetic log entries (cleared by reboot)"
tx=$(journalctl -k -b 0 --no-pager 2>/dev/null | grep -c "tx timeout" || true)
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
