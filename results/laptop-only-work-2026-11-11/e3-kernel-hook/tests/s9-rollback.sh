#!/bin/bash
# S9 (image = after S2: pin active, hooks installed): the operator's full rollback commands of
# INSTALL-AND-ROLLBACK.md, verbatim. Expect: pin file gone, grub.cfg regenerated with default 0,
# hooks gone, program gone; the module built for 38 still in place.
exec > /out/s9-rollback.log 2>&1
. /w/tests/lib.sh
setup_grub_stub
say "before"
cat /etc/default/grub.d/90-btusb-e3-pin.cfg
grep -n 'set default=' /boot/grub/grub.cfg
ls -l /lib/modules/7.0.0-38-generic/updates/
say "rollback commands"
rm /etc/kernel/postinst.d/50-btusb-e3 /etc/kernel/header_postinst.d/50-btusb-e3 /etc/kernel/postrm.d/50-btusb-e3
rm /etc/cron.daily/btusb-e3
btusb-e3 unpin
rm /usr/local/sbin/btusb-e3
rm -r /usr/local/lib/btusb-e3
say "after"
ls /etc/default/grub.d/ 2>&1
grep -n 'set default=' /boot/grub/grub.cfg
ls /etc/kernel/postinst.d/ /etc/kernel/header_postinst.d/ /etc/kernel/postrm.d/ /etc/cron.daily/
ls /usr/local/sbin /usr/local/lib
ls -l /lib/modules/7.0.0-38-generic/updates/
echo "left behind (state, cache, log): $(ls /var/lib/btusb-e3 /var/cache/btusb-e3 /var/log/btusb-e3.log 2>&1 | tr '\n' ' ')"
