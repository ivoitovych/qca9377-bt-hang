#!/bin/bash
# S7 (network on; image = after S3: 38 and 42 both with E3): running twice. The hook is run again
# through dpkg (dpkg-reconfigure) and by hand; the module must not be rebuilt or changed.
exec > /out/s7-twice.log 2>&1
. /w/tests/lib.sh
base_setup
M=/lib/modules/7.0.0-42-generic/updates/btusb.ko
say "before"
ls -l --time-style=full-iso $M
sha256sum $M
say "dpkg-reconfigure linux-image-7.0.0-42-generic (real postinst, runs the hooks)"
dpkg-reconfigure linux-image-7.0.0-42-generic 2>&1 | tail -15
say "by hand, second time"
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-42-generic /boot/vmlinuz-7.0.0-42-generic
echo "exit code $?"
say "after"
ls -l --time-style=full-iso $M
sha256sum $M
grubstate
hooklog
