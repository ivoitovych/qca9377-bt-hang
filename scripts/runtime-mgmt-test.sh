#!/bin/bash
# runtime-mgmt-test.sh — look at, and exercise, the management channel on this
# machine with the STOCK or the patched bluetoothd, around a power cycle (what
# is checked there: the held branch).
#
# Swapping the running bluetooth.ko is NOT done by this script any more: a
# module swap wedged the controller and only a power-off recovered it (EX-046,
# below), so `load` and `restore` are refused with exit 2 and the code that
# performed them is gone from this file (it is in git history:
# git log -S unload_stack -- scripts/runtime-mgmt-test.sh).
#
#   scripts/runtime-mgmt-test.sh status              what runs now (daemon, module, window); read-only
#   scripts/runtime-mgmt-test.sh stock-daemon        disable the /usr/local daemon drop-in and RESTART bluetoothd
#   scripts/runtime-mgmt-test.sh patched-daemon      re-enable the drop-in and RESTART bluetoothd
#   scripts/runtime-mgmt-test.sh trigger <label>     btmon capture + scan on + POWER-CYCLE THE ADAPTER (power off, on); decode
#
# The two daemon verbs restart bluetoothd, and `trigger` powers the adapter off
# and on through bluetoothctl: all three disturb a live controller and are not
# "usable" in the sense of harmless. Run them only when nothing else is being
# measured. The patched daemon drop-in is only moved aside, never deleted.
#
# REFUSES (exit 3) to touch Bluetooth while tools/bt-window reports an open
# untreated window or tools/bt-trial reports a trial open — that evidence
# outranks this test (BRIEF §7) — and also when it cannot tell: a missing or
# failing tools/bt-window or tools/bt-trial counts as "open". Root is required
# for everything but status.
#
# `load` and `restore` are REFUSED (exit 2) by the code. 2026-09-23: they
# WEDGED THE CONTROLLER (EX-046). Unloading and re-probing btusb on this part,
# healthy, stock module, ended with HCI Reset timing out and hci0 registered
# with an all-zero address — before any swap had even happened. The module has
# to be in place before the first probe (updates/ dir + depmod + cold boot).
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
# Fails closed: anything but a positive "no window, no trial" answer refuses.
guard() {
	local win tri wrc
	if [[ ! -x "$REPO/tools/bt-window" || ! -x "$REPO/tools/bt-trial" ]]; then
		echo "REFUSED: tools/bt-window or tools/bt-trial is missing or not executable, so an open window or trial cannot be ruled out." >&2; exit 3
	fi
	win=$("$REPO/tools/bt-window" 2>&1); wrc=$?
	tri=$("$REPO/tools/bt-trial" status 2>&1)
	if [[ "$win" == *"Untreated and running"* ]]; then
		echo "REFUSED: an untreated HCI window is open (tools/bt-window). Do not touch Bluetooth." >&2; exit 3
	fi
	if [[ "$tri" == "trial OPEN"* ]]; then
		echo "REFUSED: a trial is open (tools/bt-trial status). Close it first." >&2; exit 3
	fi
	if (( wrc != 0 )) || [[ -z "$win" ]]; then
		echo "REFUSED: tools/bt-window gave no usable answer (exit $wrc), so an open window cannot be ruled out." >&2; exit 3
	fi
	if [[ "$tri" != "no trial open"* ]]; then
		echo "REFUSED: tools/bt-trial status gave no usable answer, so an open trial cannot be ruled out." >&2; exit 3
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
load|restore)
	# Refused outright, before anything is read or run: swapping bluetooth.ko
	# on a live system wedged the controller (EX-046).
	echo "REFUSED: '$cmd' unloads and reloads btusb and bluetooth.ko on a live system; that wedged the controller (EX-046). Use a cold boot with the module in updates/ instead." >&2
	exit 2
	;;
trigger)
	guard
	label="${2:?trigger <label>}"
	stamp=$(date +%Y%m%dT%H%M%S)
	cap="$RT/$stamp-$label.btsnoop"
	echo "module: $(which_module)   daemon: $(readlink /proc/$(pidof bluetoothd)/exe)"
	btmon --columns=200 -w "$cap" >/dev/null 2>&1 &   # --columns: BT-4 aborts it at 80 on bluetoothctl's open
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
	btmon --columns=200 -r "$cap" 2>/dev/null | grep -E -A3 "Start Discovery \(0x0023\)" | grep -E "Start Discovery|Status:" | head -8
	echo "── daemon log for the same seconds:"
	journalctl _COMM=bluetoothd --since "-30s" --no-pager -o short-precise 2>/dev/null | grep -E "start_discovery_complete|Wrong size|status: 0x|segfault" | tail -6
	;;
*)
	sed -n '2,/^set -uo/{/^set -uo/!p}' "$0"; exit 2 ;;
esac
