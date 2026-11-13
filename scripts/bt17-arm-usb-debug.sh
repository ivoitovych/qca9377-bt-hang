#!/bin/bash
# bt17-arm-usb-debug.sh [--usbmon] [--off]
#
# BT-17: make the next natural loss of the Bluetooth controller (USB 3-3, 13d3:3503)
# decisive, without touching the controller. Run as root, by the operator only.
#
#   (no option)  turn on USB core dynamic debug for the resume/reset path
#                (drivers/usb/core/hub.c and driver.c): "usb auto-resume" or
#                "usb wakeup-resume" (who started the resume), "Waited Nms for CONNECT",
#                "finish resume", "retry with reset-resume", "gone after usb resume?".
#                These are kernel log lines only; nothing is sent to any device.
#   --usbmon     also start a bounded capture of USB bus 3's traffic (usbmon text,
#                in 50 MB parts under /var/log/bt-health/usbmon/; split's one-digit suffix
#                stops the capture after ten parts, 500 MB), to see
#                whether the GET_STATUS after a resume was answered at all.
#                Needs the usbmon module (loading it touches neither btusb nor bluetooth.ko).
#   --off        turn the debug lines off again and stop the capture.
#
# What it does not do: no reset, no rebind, no module reload, no sysfs power write.
# The lines it enables are low-volume except during USB enumeration; the capture of bus 3
# carries the HCI traffic of the controller, which includes device addresses: it stays
# local (/var/log/bt-health is never published).
set -u
ctl=/sys/kernel/debug/dynamic_debug/control
dir=/var/log/bt-health/usbmon
if [ "${1:-}" = "--off" ]; then
	echo 'file drivers/usb/core/hub.c -p' >"$ctl"
	echo 'file drivers/usb/core/driver.c -p' >"$ctl"
	pkill -f "bt17-usbmon-capture" && echo "usbmon capture stopped"
	echo "USB core debug off"
	exit 0
fi
[ -w "$ctl" ] || { echo "needs root and debugfs ($ctl)"; exit 2; }
echo 'file drivers/usb/core/hub.c +p' >"$ctl"
echo 'file drivers/usb/core/driver.c +p' >"$ctl"
echo "USB core debug on: $(grep -c -E 'drivers/usb/core/(hub|driver)\.c.*=p' "$ctl") sites"
if [ "${1:-}" = "--usbmon" ]; then
	modprobe usbmon || exit 1
	mkdir -p "$dir"
	# bus number of the controller's root hub (3 on this laptop): read from sysfs
	bus=$(cat /sys/bus/usb/devices/3-3/busnum 2>/dev/null || echo 3)
	nohup bash -c "exec -a bt17-usbmon-capture sh -c 'cat /sys/kernel/debug/usb/usbmon/${bus}u | split -b 50M -d -a 1 - $dir/bus${bus}-\$(date +%Y%m%d-%H%M%S)-'" \
		>/dev/null 2>&1 &
	echo "usbmon capture of bus $bus started into $dir (stop with --off; prune old parts by hand)"
fi
