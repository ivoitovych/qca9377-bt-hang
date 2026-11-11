#!/bin/bash
# S6 (network on; image = after S1): 7.0.0-43 (noble-proposed; its stock btusb is expected to carry
# the entry). Expect: hook does nothing but record; no updates/ dir; no pin. Then running twice,
# then a synthetic retire case.
exec > /out/s6-present-43.log 2>&1
. /w/tests/lib.sh
base_setup
say "install linux-image + linux-headers 7.0.0-43 (from proposed)"
kinst linux-image-7.0.0-43-generic linux-headers-7.0.0-43-generic
kstate 7.0.0-43-generic
grubstate
hooklog
say "the same hook run again by hand, twice (idempotent)"
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-43-generic /boot/vmlinuz-7.0.0-43-generic
echo "exit code $?"
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-43-generic /boot/vmlinuz-7.0.0-43-generic
echo "exit code $?"
ls -la /lib/modules/7.0.0-43-generic/updates 2>&1
say "SYNTHETIC retire case: a leftover module this tool placed earlier for 43 (dummy file + matching record)"
mkdir -p /lib/modules/7.0.0-43-generic/updates
echo dummy > /lib/modules/7.0.0-43-generic/updates/btusb.ko
S=$(sha256sum /lib/modules/7.0.0-43-generic/updates/btusb.ko | cut -d' ' -f1)
python3 -I -c "
import json
p='/var/lib/btusb-e3/kernels/7.0.0-43-generic.json'
d=json.load(open(p)); d['sha256']='$S'; json.dump(d,open(p,'w'))"
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-43-generic /boot/vmlinuz-7.0.0-43-generic
echo "exit code $?"
ls -la /lib/modules/7.0.0-43-generic/ | grep -c updates
say "and a module NOT placed by this tool must be left alone"
mkdir -p /lib/modules/7.0.0-43-generic/updates
echo foreign > /lib/modules/7.0.0-43-generic/updates/btusb.ko
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-43-generic /boot/vmlinuz-7.0.0-43-generic
cat /lib/modules/7.0.0-43-generic/updates/btusb.ko
hooklog
