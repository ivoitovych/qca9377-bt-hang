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
#
# ⚠️ 2026-09-23: `load`/`restore` WEDGED THE CONTROLLER (EX-046). Unloading and
# re-probing btusb on this part, healthy, stock module, ended with HCI Reset
# timing out and hci0 registered with an all-zero address — before any swap had
# even happened. Do not run load/restore on a live system here. The module has
# to be in place before the first probe (updates/ dir + depmod + cold boot);
# `status`, `stock-daemon`, `patched-daemon` and `trigger` remain usable.
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
	local win tri
	win=$("$REPO/tools/bt-window" 2>&1); tri=$("$REPO/tools/bt-trial" status 2>&1)
	if [[ "$win" == *"Untreated and running"* ]]; then
		echo "REFUSED: an untreated HCI window is open (tools/bt-window). Do not touch Bluetooth." >&2; exit 3
	fi
	if [[ "$tri" == "trial OPEN"* ]]; then
		echo "REFUSED: a trial is open (tools/bt-trial status). Close it first." >&2; exit 3
	fi
	[[ $EUID -eq 0 ]] || { echo "root required" >&2; exit 2; }
}

# bluetoothd is D-Bus activated: `systemctl stop` alone brings it back within a
# second (a client asks for org.bluez), and its listening sockets pin rfcomm and
# bluetooth. Mask for the duration of the swap, stop, then let modprobe order
# the removal of the whole stack.
refcounts() { lsmod | awk '$1 ~ /^(bluetooth|rfcomm|bnep|btusb)$/ {printf "%s=%s ", $1, $3} END {print ""}'; }

# Userspace re-creates Bluetooth sockets the moment a module is gone: opening an
# RFCOMM/BNEP socket makes the kernel auto-load rfcomm/bnep again, so a removal
# "succeeds" and the module is back with users before the next step. The holders
# with bluetoothd down are WirePlumber (HFP backend, per logged-in user) and
# ModemManager. They are stopped for the seconds of the swap and started again.
HOLDER_USERS=(); HOLDER_MM=0; HOLDER_UNITS=()
stop_holders() {
	# this project's own capture services hold HCI monitor sockets on bluetooth.ko
	local s
	for s in bt-capture bt-trace; do
		if systemctl is-active --quiet "$s"; then systemctl stop "$s"; HOLDER_UNITS+=("$s"); fi
	done
	if systemctl is-active --quiet ModemManager; then systemctl stop ModemManager; HOLDER_MM=1; fi
	local u
	for u in $(loginctl list-users --no-legend | awk '{print $2}'); do
		if systemctl --user -M "$u@" is-active --quiet wireplumber 2>/dev/null; then
			systemctl --user -M "$u@" stop wireplumber; HOLDER_USERS+=("$u")
		fi
	done
}
start_holders() {
	local u
	for u in "${HOLDER_USERS[@]+"${HOLDER_USERS[@]}"}"; do systemctl --user -M "$u@" start wireplumber; done
	(( HOLDER_MM )) && systemctl start ModemManager
	local s
	for s in "${HOLDER_UNITS[@]+"${HOLDER_UNITS[@]}"}"; do systemctl start "$s"; done
	return 0
}

unload_stack() {
	systemctl mask --runtime bluetooth >/dev/null 2>&1
	systemctl daemon-reload
	systemctl stop bluetooth
	stop_holders
	sleep 1
	if pidof bluetoothd >/dev/null; then
		echo "bluetoothd still running after stop+mask: $(pidof bluetoothd)" >&2
		systemctl unmask --runtime bluetooth >/dev/null 2>&1; start_holders; return 1
	fi
	echo "before unload: $(refcounts)"
	# one at a time, dependants first: btusb holds the vendor helpers, everything
	# holds bluetooth. (modprobe -r with the whole list did not keep this order.)
	local m
	# loaded-module test via sysfs: `lsmod | grep -q` under pipefail can report
	# "absent" for a loaded module when grep exits first (SIGPIPE), which made
	# the loop silently skip every module but the last on 2026-09-23.
	for m in btusb btrtl btintel btbcm btmtk btqca rfcomm bnep hidp bluetooth; do
		[[ -e /sys/module/$m/refcnt ]] || continue
		if ! modprobe -r "$m"; then
			echo "could not unload $m: $(lsmod | grep -E "^$m ")" >&2
			echo "open sockets: /sys/kernel/debug/bluetooth/{rfcomm,l2cap,sco}" >&2
			modprobe bluetooth; modprobe btusb
			systemctl unmask --runtime bluetooth >/dev/null 2>&1; systemctl daemon-reload
			systemctl start bluetooth; start_holders; return 1
		fi
	done
	echo "after unload:  $(refcounts)"
}
finish_stack() {          # after insmod/modprobe of bluetooth: btusb, service, holders
	modprobe btusb
	systemctl unmask --runtime bluetooth >/dev/null 2>&1
	systemctl daemon-reload
	systemctl start bluetooth
	start_holders
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
	unload_stack || exit 1
	if ! insmod "$ko"; then
		echo "insmod failed — restoring stock" >&2
		modprobe bluetooth; finish_stack; exit 1
	fi
	finish_stack
	sleep 2; "$0" status
	;;
restore)
	guard
	unload_stack || exit 1
	modprobe bluetooth
	finish_stack
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
