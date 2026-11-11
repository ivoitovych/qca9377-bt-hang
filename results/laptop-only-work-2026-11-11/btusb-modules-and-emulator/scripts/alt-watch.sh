#!/bin/bash
# alt-watch.sh <vid> <pid> [<seconds>] - read-only. Once a second, prints the clock time and the
# alternate setting of interface 1 (the isochronous one) of the USB device <vid>:<pid>, only when
# it changes, plus the first line. Reads /sys/bus/usb/devices/*/idVendor, idProduct and
# <dev>:1.1/bAlternateSetting. Writes nothing, never touches the device or the driver.
#   scripts/alt-watch.sh 13d3 3503 600 | tee <file>
# Stop with ctrl-c. The alternate setting is 0 with no SCO link, 1 for one transparent (mSBC)
# link, 2/4/5 for one/two/three CVSD links.
vid=${1:?vid}
pid=${2:?pid}
secs=${3:-600}
dev=""
for d in /sys/bus/usb/devices/*; do
	[ -r "$d/idVendor" ] || continue
	if [ "$(cat "$d/idVendor")" = "$vid" ] && [ "$(cat "$d/idProduct")" = "$pid" ]; then
		dev=$d
		break
	fi
done
[ -n "$dev" ] || { echo "no USB device $vid:$pid under /sys/bus/usb/devices"; exit 2; }
f=$dev:1.1/bAlternateSetting
[ -r "$f" ] || { echo "no $f"; exit 2; }
echo "$(date '+%H:%M:%S') watching $f"
last=""
i=0
while [ "$i" -lt "$secs" ]; do
	a=$(cat "$f" 2>/dev/null)
	if [ "$a" != "$last" ]; then
		echo "$(date '+%H:%M:%S.%N' | cut -c1-12) bAlternateSetting $a"
		last=$a
	fi
	sleep 1
	i=$((i + 1))
done
