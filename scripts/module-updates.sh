#!/bin/bash
# module-updates.sh — put a self-built bluetooth.ko in front of the stock one
# for the next boot, or take it away again. The steps typed by hand on
# 2026-09-24 (mkdir, install, depmod, lsinitramfs, modversions check), each of
# which prompted; as one script under the granted scripts/* rule.
#
#   scripts/module-updates.sh [--module <name>] status               what loads now and next boot
#   scripts/module-updates.sh [--module <name>] install <module.ko>  (bluetooth: check CRCs against
#                                                                    every dependant), install + depmod
#   scripts/module-updates.sh [--module <name>] remove               delete it + depmod: stock loads next boot
#
# <name> is bluetooth (default) or btusb (added 2026-09-26 for the E1 build).
# Never loads or unloads anything live: on this controller a btusb re-probe
# wedges it (EX-046). Changes take effect at the next cold boot. Root only.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KREL="$(uname -r)"
UPD="/lib/modules/$KREL/updates"
MOD=bluetooth
if [[ "${1:-}" == "--module" ]]; then MOD="${2:?--module needs a name}"; shift 2; fi
case "$MOD" in bluetooth|btusb) ;; *) echo "module must be bluetooth or btusb" >&2; exit 2 ;; esac
DST="$UPD/$MOD.ko"

status() {
	echo "module:              $MOD"
	echo "kernel:              $KREL"
	echo "loaded srcversion:   $(cat "/sys/module/$MOD/srcversion" 2>/dev/null || echo 'not loaded')"
	echo "loaded version:      $(cat "/sys/module/$MOD/version" 2>/dev/null || echo '-')"
	echo "next boot resolves:  $(modinfo -n "$MOD" 2>/dev/null)"
	if [[ -f "$DST" ]]; then
		echo "updates/ module:     srcversion $(modinfo -F srcversion "$DST")  sha256 $(sha256sum "$DST" | cut -c1-16)…"
	else
		echo "updates/ module:     none — the stock module loads"
	fi
	local inird; inird=$(lsinitramfs "/boot/initrd.img-$KREL" 2>/dev/null)
	if [[ "$inird" == *"/$MOD.ko"* ]]; then
		echo "initramfs:           CONTAINS $MOD.ko — updates/ alone is not enough; update-initramfs needed"
	else
		echo "initramfs:           no $MOD.ko — updates/ + depmod is enough"
	fi
}

case "${1:-status}" in
status) status ;;
install)
	[[ $EUID -eq 0 ]] || { echo "root required" >&2; exit 2; }
	KO="${2:?install <module.ko>}"
	[[ -f "$KO" ]] || { echo "no $KO" >&2; exit 2; }
	[[ "$(modinfo -F vermagic "$KO" | cut -d' ' -f1)" == "$KREL" ]] || { echo "vermagic of $KO is not $KREL" >&2; exit 1; }
	[[ "$(modinfo -F name "$KO")" == "$MOD" ]] || { echo "$KO is not a $MOD module" >&2; exit 1; }
	if [[ "$MOD" == bluetooth ]]; then
		SV="$(dirname "$KO")/Module.symvers"
		[[ -f "$SV" ]] || SV="$REPO/tmp/bt-build/net/bluetooth/Module.symvers"
		[[ -f "$SV" ]] || { echo "no Module.symvers beside $KO to check CRCs against" >&2; exit 1; }
		mapfile -t DEPS < <(find "/lib/modules/$KREL/kernel/drivers/bluetooth" "/lib/modules/$KREL/kernel/net/bluetooth" \
			-name '*.ko*' ! -name 'bluetooth.ko*' \( -name 'btusb*' -o -name 'btintel.*' -o -name 'btbcm*' -o -name 'btrtl*' \
			-o -name 'btmtk.*' -o -name 'btqca*' -o -name 'rfcomm*' -o -name 'bnep*' -o -name 'hidp*' \))
		"$REPO/scripts/check-modversions.sh" "$SV" "${DEPS[@]}" || { echo "NOT installed" >&2; exit 1; }
	else
		# btusb exports nothing another module imports; its own imports were
		# resolved against this kernel's Module.symvers when it was built.
		echo "no dependants import from $MOD — no CRC check needed"
	fi
	mkdir -p "$UPD"
	install -m 644 "$KO" "$DST"
	depmod -a "$KREL"
	status
	echo "takes effect at the next cold boot"
	;;
remove)
	[[ $EUID -eq 0 ]] || { echo "root required" >&2; exit 2; }
	[[ -f "$DST" ]] && rm -f "$DST"
	depmod -a "$KREL"
	status
	echo "the stock module loads at the next boot"
	;;
*) sed -n '2,13p' "$0"; exit 2 ;;
esac
