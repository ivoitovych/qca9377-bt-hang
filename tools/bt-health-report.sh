#!/bin/bash
# bt-health-report.sh — judge whether the mitigations are working.
#
# Run this after a day or two of normal use (and at least one cold power-off):
#     /usr/local/bin/bt-health-report
#
# Data sources:
#   /var/log/bt-health/metrics.tsv   periodic snapshots (survive reboots)
#   journalctl                        per-boot failure counts (35 boots retained)
#   evidence/baseline/baseline.tsv                      pre-mitigation measurements, for comparison

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS=/var/log/bt-health/metrics.tsv

# The baseline ships with the repo but this script may be installed to
# /usr/local/bin, so look in the likely places rather than assuming $DIR.
BASELINE=""
for cand in \
    "${BT_BASELINE:-}" \
    "$DIR/evidence/baseline/baseline.tsv" \
    "$DIR/../evidence/baseline/baseline.tsv" \
    /usr/local/share/qca9377-bt-hang/baseline.tsv \
    /var/log/bt-health/baseline.tsv
do
    [[ -n "$cand" && -s "$cand" ]] && { BASELINE="$cand"; break; }
done
VID="${BT_VID:-13d3}"
PID="${BT_PID:-3503}"

# Timestamp the mitigations were installed; boots after this are tagged AFTER.
# Defaults to the mtime of the watchdog unit if not set explicitly.
# Prefer the stamp install.sh writes once. A unit file's mtime moves forward on
# every reinstall, which would relabel already-mitigated boots as "before".
STAMP=/usr/local/share/qca9377-bt-hang/installed-at
if [[ -n "${BT_CHANGE_TIME:-}" ]]; then
    CHANGE_EPOCH=$(date -d "$BT_CHANGE_TIME" +%s 2>/dev/null || echo 0)
elif [[ -s "$STAMP" ]]; then
    CHANGE_EPOCH=$(cat "$STAMP")
elif [[ -e /etc/systemd/system/bt-hang-watchdog.service ]]; then
    # Fallback only; see above for why this can mislabel.
    CHANGE_EPOCH=$(stat -c %Y /etc/systemd/system/bt-hang-watchdog.service)
else
    CHANGE_EPOCH=0
fi


# Locate bt-boot-list next to this script, then on PATH. Enumerating boots is
# subtle enough (see that script's header) that it must not be reimplemented.
_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTLIST=""
for c in "$_here/bt-boot-list" "$_here/../tools/bt-boot-list" /usr/local/bin/bt-boot-list; do
    [[ -x "$c" ]] && { BOOTLIST="$c"; break; }
done
[[ -n "$BOOTLIST" ]] || BOOTLIST=""
boot_indices() {
    if [[ -n "$BOOTLIST" ]]; then "$BOOTLIST" ${1:+-n "$1"}
    else journalctl --list-boots 2>/dev/null | awk '$1 ~ /^-?[0-9]+$/ {print $1}' | sort -n; fi
}

hr() { printf '%s\n' "────────────────────────────────────────────────────────────────"; }

echo "BLUETOOTH MITIGATION EFFECTIVENESS REPORT"
echo "generated: $(date -Iseconds)"
hr

# ── 1. Are the mitigations actually in force? ─────────────────────────────
echo "1. MITIGATION STATE"
printf '   %-34s %s\n' "watchdog service:" "$(systemctl is-active bt-hang-watchdog 2>/dev/null)"
printf '   %-34s %s\n' "metrics timer:" "$(systemctl is-active bt-health-snapshot.timer 2>/dev/null)"
printf '   %-34s %s\n' "btusb enable_autosuspend:" "$(cat /sys/module/btusb/parameters/enable_autosuspend 2>/dev/null || echo 'module not loaded')"

ctrl="device absent"
for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" ]] || continue
    if [[ "$(<"$d/idVendor")" == "$VID" && "$(<"$d/idProduct")" == "$PID" ]]; then
        ctrl="$(cat "$d/power/control" 2>/dev/null)  [$(basename "$d")]"
        break
    fi
done
printf '   %-34s %s\n' "BT usb power/control:" "$ctrl"
echo
echo "   expected after a cold power-off: autosuspend=N, power/control=on"
hr

# ── 2. Per-boot failure counts, before vs after ───────────────────────────
echo "2. PER-BOOT FAILURE COUNTS (all retained boots)"
echo
printf '   %-6s %-22s %-9s %-9s %-8s %s\n' BOOT KERNEL TIMEOUTS UNEXPECT WD-ACTS PHASE
for b in $(boot_indices); do
    k=$(journalctl -k -b "$b" 2>/dev/null | grep -m1 -oE "Linux version [0-9][^ ]*" | awk '{print $3}')
    [[ -z "${k:-}" ]] && continue
    # HCI command timeouts, opcode-named or not. NOT bare "tx timeout": that
    # also matches `link tx timeout` (ACL supervision, a different layer), of
    # which this machine has logged 7 against 173 real command timeouts. See
    # evidence/exhibits/015-timeout-pattern-undercount.md.
    t=$(journalctl -k -b "$b" 2>/dev/null | grep -cE "command( 0x[0-9a-f]+)? tx timeout")
    u=$(journalctl -k -b "$b" 2>/dev/null | grep -c "unexpected event for opcode")
    w=$(journalctl -u bt-hang-watchdog -b "$b" 2>/dev/null | grep -cE "intervening|EARLY intervention")
    # FIRST entry of the boot, not -n1 (which returns the LAST). Using the
    # last entry tags the install boot as AFTER and drags its pre-install
    # timeout counts into the after column, contaminating the comparison.
    bstart=$(journalctl -k -b "$b" -o short-unix 2>/dev/null | head -1 | awk '{printf "%d",$1}')
    phase="before"
    [[ -n "${bstart:-}" ]] && (( bstart > CHANGE_EPOCH )) && phase="AFTER"
    printf '   %-6s %-22s %-9s %-9s %-8s %s\n' "$b" "$k" "$t" "$u" "$w" "$phase"
done
echo
if [[ -n "${BT_SYNTHETIC_NOTE:-}" ]]; then
    echo "   note: $BT_SYNTHETIC_NOTE"
fi
hr

# ── 3. Watchdog outcomes — kept separate from causal interpretation ───────
echo "3. WATCHDOG OUTCOMES"
echo
wd=$(journalctl -u bt-hang-watchdog --no-pager 2>/dev/null)
acts=$(grep -cE "intervening|EARLY intervention"      <<<"$wd")
confirmed_recs=$(grep -c "RECOVERED — confirmed stalled controller" <<<"$wd")
legacy_recs=$(grep -c "RECOVERED — controller is responding again" <<<"$wd")
early_recs=$(grep -cE "EARLY recovery SUCCEEDED|CONTROLLER RESPONDS AFTER EARLY INTERVENTION" <<<"$wd")
fails=$(grep -c "RECOVERY FAILED" <<<"$wd")
hard=$(grep -c "FATAL:"           <<<"$wd")
printf '   %-38s %s\n' "interventions attempted:" "$acts"
printf '   %-38s %s\n' "  -> confirmed post-timeout recovery:" "$confirmed_recs"
printf '   %-38s %s\n' "  -> answered after early action:" "$early_recs"
printf '   %-38s %s\n' "  -> legacy RECOVERED (context mixed):" "$legacy_recs"
printf '   %-38s %s\n' "  -> HCI not restored:" "$fails"
printf '   %-38s %s\n' "  -> controller observed USB-absent:" "$hard"
wd_now=$(journalctl -u bt-hang-watchdog -b 0 --no-pager 2>/dev/null)
acts_now=$(grep -cE "intervening|EARLY intervention" <<<"$wd_now")
printf '   %-38s %s\n' "this boot only:" "$acts_now intervention(s)"
echo
# LIVE STATE BEFORE COUNTERS. The counters above span the whole retained
# journal, so one historical recovery would otherwise print "WORKING" while
# the controller is off the bus right now — the exact masking flaw fixed in
# bt-status and bt-postmortem after 2026-08-11, surviving here as a third
# instance. A tool that reports success during a failure is worse than none.
hci_now=$(ls -A /sys/class/bluetooth/ 2>/dev/null | head -1)
if [[ -z "$hci_now" ]]; then
    on_bus=no
    for d in /sys/bus/usb/devices/*; do
        [[ -f "$d/idVendor" ]] || continue
        [[ "$(<"$d/idVendor")" == "$VID" && "$(<"$d/idProduct")" == "$PID" ]] \
            && { on_bus=yes; break; }
    done
    echo "   VERDICT: CONTROLLER IS DOWN RIGHT NOW — no hci device exists."
    echo "            (on USB bus: $on_bus. Historical counters above cannot"
    echo "            outrank live state; see bt-postmortem for this incident.)"
elif (( acts == 0 )); then
    echo "   VERDICT: no watchdog intervention is recorded."
    echo "            This does not imply that no timeout occurred; inspect the"
    echo "            per-boot timeout and usage counts separately."
elif (( confirmed_recs > 0 )); then
    echo "   VERDICT: $confirmed_recs confirmed post-timeout HCI recovery event(s) recorded."
    echo "            Compare incidence and later USB state separately."
elif (( legacy_recs > 0 )); then
    echo "   VERDICT: $legacy_recs legacy RECOVERED marker(s) have mixed context."
    echo "            Aggregate old logs cannot separate early-action responses"
    echo "            from post-timeout recovery; inspect incident chronology."
else
    if (( acts_now == 0 )); then
        echo "   VERDICT: the $acts intervention(s) all predate the current boot."
        echo "            They are historical interventions from before the"
        echo "            cold power-off, not a failure of the mitigation. Nothing"
        echo "            has fired since. Keep measuring."
    else
        echo "   VERDICT: watchdog fired $acts_now time(s) THIS BOOT and never"
        echo "            restored HCI. If USB absence followed, do not assume the"
        echo "            controller naturally degraded or that lowering the threshold"
        echo "            is safer; reset may itself alter the trajectory."
    fi
fi
hr

# ── 4. Recent snapshot rows ────────────────────────────────────────────────
echo "4. RECENT SNAPSHOTS (last 15)"
echo
if [[ -s "$METRICS" ]]; then
    { head -1 "$METRICS"; tail -n +2 "$METRICS" | tail -15; } | column -t -s $'\t' | sed 's/^/   /'
    echo
    echo "   rows collected: $(( $(wc -l < "$METRICS") - 1 ))"
else
    echo "   no metrics yet — timer runs every 15 min"
fi
hr

# ── 5. Baseline comparison ─────────────────────────────────────────────────
echo "5. BASELINE (measured before any mitigation)"
echo
if [[ -n "$BASELINE" && -s "$BASELINE" ]]; then
    column -t -s $'\t' "$BASELINE" | sed 's/^/   /'
else
    echo "   baseline not found (set BT_BASELINE=/path/to/baseline.tsv)"
fi
hr

echo "6. WHAT TO LOOK FOR"
cat <<'EOF'
   Keep four quantities separate:
     a) BT-1 incidence under a controlled exposure denominator
     b) confirmed HCI recovery after timeout
     c) USB errors/disappearance after intervention
     d) final controller state

   A lower timeout count does not identify autosuspend as the cause. USB absence
   after a reset does not prove natural progression or justify a lower threshold.

   Live view: journalctl -u bt-hang-watchdog -f
EOF
