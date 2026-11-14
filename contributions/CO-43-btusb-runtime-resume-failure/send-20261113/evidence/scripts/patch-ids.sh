#!/bin/bash
# patch-ids.sh: git patch-id --stable of the reviewed CO-43 patches (project, read-only) and of the
# package's patches: equal ids mean the code change is unchanged (messages are not part of the id).
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
c=/root/exp/qca9377-bt-hang/contributions/CO-43-btusb-runtime-resume-failure/patch
for f in "$c/0004-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch" \
	"$w/package/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch" \
	"$c/0001-Bluetooth-btusb-Report-a-failed-resume-for-deferred-.patch" \
	"$w/package/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch"; do
	echo "$(git patch-id --stable <"$f" | cut -d' ' -f1)  $f"
done
