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
run state-env
echo "unit default, e1 loaded:    $(grep -E '^build' "$LC/state-env/current" 2>/dev/null | tr '\n' ' ')"
run state-arg stock
echo "explicit stock, e1 loaded:  $(grep -E '^build' "$LC/state-arg/current" 2>/dev/null | tr '\n' ' ')"
echo 0.8 > "$LC/sysmod/btusb/version"
run state-plain
echo "unit default, stock loaded: $(grep -E '^build' "$LC/state-plain/current" 2>/dev/null | tr '\n' ' ')"
rm -rf "$LC"
