#!/bin/bash
# prove-trial-build-label.sh — standalone proof of the suite's autostart build-label
# check, for when the suite cannot run (trial open): with btusb 0.8-e1 loaded and
# the unit's BT_BUILD=stock, the trial opens as E1 with build_declared=stock; an
# explicit "stock" argument stands; a plain 0.8 stays stock.
#
#   scripts/prove-trial-build-label.sh [bt-trial]   default: this repository's tools/bt-trial
#
# bt-state is stubbed: the real one reads the whole journal and hung the first run.
set -uo pipefail
T="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/tools/bt-trial}"
LC=$(mktemp -d)
mkdir -p "$LC/bin" "$LC/sysfs/3-3/3-3:1.0/bluetooth/hci0" "$LC/sysfs/3-3/power" "$LC/sysmod/btusb"
for stub in hciconfig bt-incident bt-state; do printf '#!/bin/sh\nexit 0\n' > "$LC/bin/$stub"; chmod +x "$LC/bin/$stub"; done
echo 13d3 > "$LC/sysfs/3-3/idVendor"; echo 3503 > "$LC/sysfs/3-3/idProduct"; echo on > "$LC/sysfs/3-3/power/control"
echo 0.8-e1 > "$LC/sysmod/btusb/version"
run() {
	PATH="$LC/bin:$PATH" BT_REPO="$LC" BT_EVIDENCE_REPO="$LC" BT_STATE="$LC/$1" \
		BT_SYSFS_USB="$LC/sysfs" BT_SYSFS_MODULE="$LC/sysmod" BT_BUILD=stock \
		timeout 30 "$T" autostart "${@:2}" >/dev/null 2>&1
}
FAILED=0
expect() {   # <label> <state dir> <wanted line>... — every wanted line must be in the state file
	local label="$1" d="$2" l; shift 2
	local got; got="$(grep -E '^build' "$LC/$d/current" 2>/dev/null | tr '\n' ' ')"
	for l in "$@"; do
		grep -qx "$l" "$LC/$d/current" 2>/dev/null || { echo "  ✗ $label: wanted '$l', got: ${got:-nothing}"; FAILED=$((FAILED + 1)); return; }
	done
	echo "  ✓ $label: $got"
}
run state-env
expect "unit default, e1 loaded   " state-env build=E1 build_declared=stock
run state-arg stock
expect "explicit stock, e1 loaded " state-arg build=stock
echo 0.8 > "$LC/sysmod/btusb/version"
run state-plain
expect "unit default, stock loaded" state-plain build=stock
rm -rf "$LC"
# the exit status is the proof's: 0 only when all three held
(( FAILED == 0 ))
