#!/bin/bash
# S3 (network on; image = after S2): the daily retry (cron.daily script) finds the failed kernel,
# builds E3 for 7.0.0-42, the pin removes itself and grub.cfg is regenerated.
exec > /out/s3-retry-online.log 2>&1
. /w/tests/lib.sh
base_setup
say "before"
btusb-e3 status
say "run /etc/cron.daily/btusb-e3"
/etc/cron.daily/btusb-e3
echo "cron script exit code: $?"
kstate 7.0.0-42-generic
grubstate
hooklog
say "compare with the E3 module built by hand on the laptop (project tmp/runtime-e3-7.0.0-42)"
H=/proj/tmp/runtime-e3-7.0.0-42/btusb.ko
ls -l $H
echo "laptop-built srcversion: $(modinfo -F srcversion $H)"
echo "laptop-built vermagic:   $(modinfo -F vermagic $H)"
echo "laptop-built sha256:     $(sha256sum $H | cut -d' ' -f1)"
echo "expected srcversion from the task: DDB92562D1890FC3D262993"
python3 -I /proj/scripts/btusb-has-device.py $H
cmp /lib/modules/7.0.0-42-generic/updates/btusb.ko $H && echo "BYTE-IDENTICAL to the laptop build" || echo "bytes differ from the laptop build (expected per the tooling index)"
