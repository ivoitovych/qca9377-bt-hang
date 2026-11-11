#!/bin/bash
# collect.sh - copy the built modules into modules/pair-A and modules/pair-B with
# Module.symvers and SHA256SUMS, and print the checks. Reads and copies only.
#   pair-A: bluetooth.ko (CO-21 core, test storage) + btusb.ko (E3 + CO-21)
#   pair-B: the same bluetooth.ko + btusb.ko (E3 + CO-21 + CO-20)
set -u
w=/root/exp/agent-work/laptop-btusb-modules-20261111
p=/root/exp/qca9377-bt-hang
for s in pair-A pair-B; do
	[ -e "$w/modules/$s" ] && { echo "exists: $w/modules/$s"; exit 2; }
	mkdir -p "$w/modules/$s"
	cp "$w/build/co21s/net/bluetooth/bluetooth.ko" "$w/modules/$s/bluetooth.ko" || exit 2
	cp "$w/build/co21s/net/bluetooth/Module.symvers" "$w/modules/$s/Module.symvers" || exit 2
done
cp "$w/build/co21s/drivers/bluetooth/btusb.ko" "$w/modules/pair-A/btusb.ko" || exit 2
cp "$w/build/co21s20/drivers/bluetooth/btusb.ko" "$w/modules/pair-B/btusb.ko" || exit 2
for s in pair-A pair-B; do
	(cd "$w/modules/$s" && sha256sum bluetooth.ko btusb.ko Module.symvers >SHA256SUMS)
	echo "=== $s"
	cat "$w/modules/$s/SHA256SUMS"
	for m in bluetooth btusb; do
		ko="$w/modules/$s/$m.ko"
		echo "$m: srcversion $(modinfo -F srcversion "$ko")  vermagic $(modinfo -F vermagic "$ko")  size $(stat -c %s "$ko")"
	done
	python3 -I "$p/scripts/btusb-has-device.py" "$w/modules/$s/btusb.ko"
	python3 -I "$p/scripts/btusb-has-device.py" "$w/modules/$s/btusb.ko" 0cf3 e300
done
echo "=== stock for comparison"
echo "stock bluetooth srcversion $(modinfo -F srcversion /lib/modules/7.0.0-42-generic/kernel/net/bluetooth/bluetooth.ko.zst)"
echo "stock btusb srcversion $(modinfo -F srcversion /lib/modules/7.0.0-42-generic/kernel/drivers/bluetooth/btusb.ko.zst)"
python3 -I "$p/scripts/btusb-has-device.py" /lib/modules/7.0.0-42-generic/kernel/drivers/bluetooth/btusb.ko.zst
echo "installed E3: $(modinfo -F srcversion /lib/modules/7.0.0-42-generic/updates/btusb.ko)"
