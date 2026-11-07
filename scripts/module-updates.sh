#!/bin/bash
# module-updates.sh — put a self-built bluetooth.ko in front of the stock one
# for the next boot, or take it away again. The steps typed by hand on
# 2026-09-24 (mkdir, install, depmod, lsinitramfs, modversions check), each of
# which prompted; as one script under the granted scripts/* rule.
#
#   scripts/module-updates.sh [--krel <release>] [--module <name>] …  another installed kernel
#   scripts/module-updates.sh [--module <name>] status               what loads now and next boot
#   scripts/module-updates.sh [--module <name>] check <module.ko>    every check of install, nothing written
#   scripts/module-updates.sh [--module <name>] install <module.ko> [--trial-open-ok]
#                                                                    (bluetooth: check CRCs against
#                                                                    every dependant), install + depmod
#   scripts/module-updates.sh [--module <name>] remove               delete it + depmod: stock loads next boot
#
# <name> is bluetooth (default) or btusb (added 2026-09-26 for the E1 build).
# Never loads or unloads anything live: on this controller a btusb re-probe
# wedges it (EX-046). Changes take effect at the next cold boot. install and
# remove need root; status and check do not.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KREL="$(uname -r)"
# --krel <release>: act on an installed kernel that is not running (added
# 2026-10-10: E3 for 7.0.0-38 before its first boot). Must come first.
if [[ "${1:-}" == "--krel" ]]; then KREL="${2:?--krel needs a release}"; shift 2; fi
[[ -d "/lib/modules/$KREL" ]] || { echo "no /lib/modules/$KREL" >&2; exit 2; }
UPD="/lib/modules/$KREL/updates"
MOD=bluetooth
if [[ "${1:-}" == "--module" ]]; then MOD="${2:?--module needs a name}"; shift 2; fi
case "$MOD" in bluetooth|btusb) ;; *) echo "module must be bluetooth or btusb" >&2; exit 2 ;; esac
DST="$UPD/$MOD.ko"

status() {
	echo "module:              $MOD"
	echo "kernel:              $KREL$([[ "$KREL" != "$(uname -r)" ]] && echo "  (not the running kernel, $(uname -r))")"
	if [[ "$KREL" == "$(uname -r)" ]]; then
		echo "loaded srcversion:   $(cat "/sys/module/$MOD/srcversion" 2>/dev/null || echo 'not loaded')"
		echo "loaded version:      $(cat "/sys/module/$MOD/version" 2>/dev/null || echo '-')"
	fi
	echo "next boot resolves:  $(modinfo -k "$KREL" -n "$MOD" 2>/dev/null)"
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

# Every check install makes; writes nothing, needs no root. Exit 1 on any failure.
precheck() {
	local KO="$1"
	[[ -f "$KO" ]] || { echo "no $KO" >&2; return 2; }
	[[ "$(modinfo -F vermagic "$KO" | cut -d' ' -f1)" == "$KREL" ]] || { echo "vermagic of $KO is not $KREL" >&2; return 1; }
	[[ "$(modinfo -F name "$KO")" == "$MOD" ]] || { echo "$KO is not a $MOD module" >&2; return 1; }
	local dir; dir="$(dirname "$KO")"
	# A SHA256SUMS beside the module (the CO-02 builds write one) must still match.
	if [[ -f "$dir/SHA256SUMS" ]]; then
		(cd "$dir" && sha256sum --quiet -c SHA256SUMS) || { echo "SHA256SUMS beside $KO does not match" >&2; return 1; }
	fi
	if [[ "$MOD" == bluetooth ]]; then
		# The Module.symvers of the SAME build, nothing else: until 2026-10-23 a
		# missing one fell back to tmp/bt-build's, which may be another build's.
		local SV="$dir/Module.symvers"
		[[ -f "$SV" ]] || { echo "no Module.symvers beside $KO: copy the one from the same build" >&2; return 1; }
		# It must describe this module: the same exported names.
		if ! diff -q <(nm "$KO" | sed -n 's/.* __crc_//p' | sort) <(cut -f2 "$SV" | sort) > /dev/null; then
			echo "Module.symvers beside $KO does not list the module's own exports" >&2; return 1
		fi
		# Every module that depends on bluetooth.ko, from modules.dep: updates/
		# included (E3's btusb is there). Until 2026-10-23 this was a name list
		# under kernel/ only, which missed updates/btusb.ko and most drivers.
		local DEPS
		mapfile -t DEPS < <(awk -F': ' -v k="/lib/modules/$KREL/" \
			'$2 ~ /(^| )(kernel\/net\/bluetooth|updates)\/bluetooth\.ko(\.[a-z]+)?( |$)/ { print k $1 }' \
			"/lib/modules/$KREL/modules.dep")
		(( ${#DEPS[@]} )) || { echo "no dependants of bluetooth.ko in modules.dep" >&2; return 1; }
		echo "dependants of bluetooth.ko in $KREL: ${#DEPS[@]}"
		"$REPO/scripts/check-modversions.sh" "$SV" "${DEPS[@]}" || return 1
	else
		# btusb exports nothing another module imports; its own imports were
		# resolved against this kernel's Module.symvers when it was built.
		echo "no dependants import from $MOD — no CRC check needed"
	fi
}

case "${1:-status}" in
status) status ;;
check)
	precheck "${2:?check <module.ko>}" || { echo "NOT ready to install" >&2; exit 1; }
	echo "ready to install: $2"
	;;
install)
	[[ $EUID -eq 0 ]] || { echo "root required" >&2; exit 2; }
	KO="${2:?install <module.ko>}"
	# A new module changes the conditions of an open trial (BRIEF §7): close it
	# first, or say on the command line that it stays open.
	if [[ -e /run/bt-trial/current && "${3:-}" != --trial-open-ok ]]; then
		echo "a trial is open (/run/bt-trial/current): close it first, or add --trial-open-ok" >&2; exit 1
	fi
	precheck "$KO" || { echo "NOT installed" >&2; exit 1; }
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
*) sed -n '2,18p' "$0"; exit 2 ;;
esac
