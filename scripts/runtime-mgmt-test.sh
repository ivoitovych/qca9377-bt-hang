#!/bin/bash
# runtime-mgmt-test.sh — run the held kernel patch on this machine: swap the
# running bluetooth.ko for one built from Ubuntu's own source (unpatched
# control or patched), with the STOCK distro bluetoothd, and capture what the
# kernel answers to a Start Discovery that is pending when the adapter powers
# off. Everything is reversible; a reboot restores the stock module and the
# patched daemon drop-in is only moved aside, never deleted.
#
#   scripts/runtime-mgmt-test.sh status              what runs now (daemon, module, window)
#   scripts/runtime-mgmt-test.sh stock-daemon        disable the /usr/local daemon drop-in
#   scripts/runtime-mgmt-test.sh patched-daemon      re-enable it
#   scripts/runtime-mgmt-test.sh load unpatched|patched   swap bluetooth.ko (tmp/runtime/)
#   scripts/runtime-mgmt-test.sh restore             back to the stock on-disk bluetooth.ko
#   scripts/runtime-mgmt-test.sh trigger <label>     btmon capture + scan on + power off; decode
#
# REFUSES to touch Bluetooth while tools/bt-window reports an open untreated
# window or tools/bt-trial reports a trial open — that evidence outranks this
# test (BRIEF §7). Root required for everything but status.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DROPIN=/etc/systemd/system/bluetooth.service.d/20-patched-bluetoothd.conf
RT="$REPO/tmp/runtime"
cmd="${1:-status}"

srcver() { modinfo -F srcversion "$1" 2>/dev/null; }
loaded_srcver() { cat /sys/module/bluetooth/srcversion 2>/dev/null || echo "not loaded"; }
which_module() {
	local cur; cur=$(loaded_srcver)
	for v in unpatched patched; do
		[[ "$cur" == "$(srcver "$RT/bluetooth-$v.ko")" ]] && { echo "$v (tmp/runtime)"; return; }
	done
	[[ "$cur" == "$(modinfo -F srcversion bluetooth 2>/dev/null)" ]] && { echo "stock (on disk)"; return; }
	echo "unknown ($cur)"
}
guard() {
	if "$REPO/tools/bt-window" 2>&1 | grep -q "Untreated and running"; then
		echo "REFUSED: an untreated HCI window is open (tools/bt-window). Do not touch Bluetooth." >&2; exit 3
	fi
	if "$REPO/tools/bt-trial" status 2>&1 | grep -q "^trial OPEN"; then
		echo "REFUSED: a trial is open (tools/bt-trial status). Close it first." >&2; exit 3
	fi
	[[ $EUID -eq 0 ]] || { echo "root required" >&2; exit 2; }
}

case "$cmd" in
status)
	echo "daemon drop-in : $([[ -f $DROPIN ]] && echo "ENABLED (patched /usr/local daemon)" || echo "disabled (stock daemon)")"
	pid=$(pidof bluetoothd || true)
	if [[ -n "$pid" ]]; then echo "daemon running : $(readlink /proc/$pid/exe) (pid $pid)"; else echo "daemon running : none"; fi
	echo "bluetooth.ko   : $(which_module)"
	echo "window         : $("$REPO/tools/bt-window" 2>&1 | grep -E "Untreated|no open|closed" | head -1)"
	echo "trial          : $("$REPO/tools/bt-trial" status 2>&1 | head -1)"
	ls "$RT"/bluetooth-*.ko 2>/dev/null | sed 's/^/built          : /'
	;;
stock-daemon)
	guard
	[[ -f $DROPIN ]] && mv "$DROPIN" "$DROPIN.disabled"
	systemctl daemon-reload && systemctl restart bluetooth
	sleep 1; "$0" status
	;;
patched-daemon)
	guard
	[[ -f $DROPIN.disabled ]] && mv "$DROPIN.disabled" "$DROPIN"
	systemctl daemon-reload && systemctl restart bluetooth
	sleep 1; "$0" status
	;;
load)
	guard
	v="${2:?load unpatched|patched}"
	ko="$RT/bluetooth-$v.ko"; [[ -f $ko ]] || { echo "no $ko — build it first" >&2; exit 2; }
	systemctl stop bluetooth
	# unload every module that depends on bluetooth, then bluetooth itself
	for m in rfcomm bnep hidp btusb btrtl btintel btbcm btmtk btqca; do
		lsmod | grep -q "^$m " && modprobe -r "$m"
	done
	lsmod | grep -q "^bluetooth " && rmmod bluetooth
	insmod "$ko" || { echo "insmod failed — restoring stock" >&2; modprobe bluetooth; modprobe btusb; systemctl start bluetooth; exit 1; }
	modprobe btusb
	systemctl start bluetooth
	sleep 2; "$0" status
	;;
restore)
	guard
	systemctl stop bluetooth
	for m in rfcomm bnep hidp btusb btrtl btintel btbcm btmtk btqca; do
		lsmod | grep -q "^$m " && modprobe -r "$m"
	done
	lsmod | grep -q "^bluetooth " && rmmod bluetooth
	modprobe bluetooth && modprobe btusb && systemctl start bluetooth
	sleep 2; "$0" status
	;;
trigger)
	guard
	label="${2:?trigger <label>}"
	stamp=$(date +%Y%m%dT%H%M%S)
	cap="$RT/$stamp-$label.btsnoop"
	echo "module: $(which_module)   daemon: $(readlink /proc/$(pidof bluetoothd)/exe)"
	btmon -w "$cap" >/dev/null 2>&1 &
	mon=$!
	sleep 1
	bluetoothctl power on >/dev/null
	sleep 2
	# a Start Discovery that is still pending when the adapter powers off
	bluetoothctl --timeout 3 scan on >/dev/null 2>&1 &
	sleep 0.3
	bluetoothctl power off >/dev/null
	sleep 3
	bluetoothctl power on >/dev/null
	sleep 1
	kill "$mon"; wait "$mon" 2>/dev/null
	echo "capture: $cap"
	echo "── the kernel's answer to Start Discovery (mgmt channel):"
	btmon -r "$cap" 2>/dev/null | grep -E -A3 "Start Discovery \(0x0023\)" | grep -E "Start Discovery|Status:" | head -8
	echo "── daemon log for the same seconds:"
	journalctl _COMM=bluetoothd --since "-30s" --no-pager -o short-precise 2>/dev/null | grep -E "start_discovery_complete|Wrong size|status: 0x|segfault" | tail -6
	;;
*)
	sed -n '2,20p' "$0"; exit 2 ;;
esac
