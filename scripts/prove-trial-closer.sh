#!/bin/bash
# prove-trial-closer.sh — standalone proof of the suite's two bt-trial closer checks,
# for when the suite cannot run (trial open): an unclosed trial directory is set
# aside at the next autostart, and a journal too slow for BT_TRIAL_SCAN_BUDGET
# costs the descriptive counts, never the row or the verdict.
#
#   scripts/prove-trial-closer.sh
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
LC=$(mktemp -d)
ok()  { echo "  ✓ $*"; }
bad() { echo "  ✗ $*"; }
mkdir -p "$LC/bin" "$LC/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$LC/sysfs/3-3/power"
for s in hciconfig bt-incident bt-state; do printf '#!/bin/sh\nexit 0\n' > "$LC/bin/$s"; chmod +x "$LC/bin/$s"; done
echo 13d3 > "$LC/sysfs/3-3/idVendor"; echo 3503 > "$LC/sysfs/3-3/idProduct"; echo on > "$LC/sysfs/3-3/power/control"

mkdir -p "$LC/ev-set/evidence/trials/stock/trial-01"
echo old > "$LC/ev-set/evidence/trials/stock/trial-01/state-before.txt"
PATH="$LC/bin:$PATH" BT_REPO="$LC/ev-set" BT_EVIDENCE_REPO="$LC/ev-set" BT_STATE="$LC/state-set" \
    BT_SYSFS_USB="$LC/sysfs" tools/bt-trial autostart stock >/dev/null 2>&1
ASIDE=$(ls -d "$LC/ev-set/evidence/trials/stock/trial-01.unclosed-"* 2>/dev/null | head -1)
if [[ -n "$ASIDE" && "$(cat "$ASIDE/state-before.txt" 2>/dev/null)" == old \
      && -e "$LC/ev-set/evidence/trials/stock/trial-01/steps.log" ]]; then
    ok "autostart sets an unclosed trial directory aside instead of writing over it"
else
    bad "autostart over an existing trial-01 directory: aside='$ASIDE'"
fi

mkdir -p "$LC/slow/bin"
cat > "$LC/slow/bin/journalctl" <<'STUB'
#!/bin/sh
fast=0
for a in "$@"; do [ "$a" = "-p" ] && fast=1; done
for a in "$@"; do
  if [ "$a" = "-k" ]; then
    if [ "$fast" = 1 ]; then
      printf '2026-09-27T10:00:00.000000+02:00 n kernel: Bluetooth: hci0: command 0x0406 tx timeout\n'
    else
      sleep 5
    fi
    exit 0
  fi
done
exit 0
STUB
chmod +x "$LC/slow/bin/journalctl"
export BT_TRIAL_SCAN_BUDGET=1
PATH="$LC/slow/bin:$LC/bin:$PATH" BT_REPO="$LC/slow" BT_EVIDENCE_REPO="$LC/slow" BT_STATE="$LC/state-slow" \
    BT_SYSFS_USB="$LC/sysfs" tools/bt-trial autostart stock >/dev/null 2>&1
t0=$(date +%s)
SLOWOUT=$(PATH="$LC/slow/bin:$LC/bin:$PATH" BT_REPO="$LC/slow" BT_EVIDENCE_REPO="$LC/slow" BT_STATE="$LC/state-slow" \
    BT_SYSFS_USB="$LC/sysfs" tools/bt-trial ok 2>&1); slowrc=$?
echo "  close took $(( $(date +%s) - t0 )) s"
unset BT_TRIAL_SCAN_BUDGET
SLOWROW=$(awk -F'\t' 'NR == 2 { print $8, $11, $13 }' "$LC/slow/evidence/trials/results.tsv" 2>/dev/null)
if [[ "$SLOWROW" == "confirmed ? 1" ]]; then
    ok "a journal too slow for the budget costs the descriptive counts, never the row or the verdict"
else
    bad "slow-journal close: rc=$slowrc row (bt1_status sco_sent timeouts)='$SLOWROW'"
    echo "$SLOWOUT"
fi
rm -rf "$LC"
