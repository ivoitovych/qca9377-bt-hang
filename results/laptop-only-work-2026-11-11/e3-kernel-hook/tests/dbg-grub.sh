#!/bin/bash
exec > /out/dbg-grub3.log 2>&1
. /w/tests/lib.sh
setup_grub_stub
rm -f /boot/grub/grub.cfg
echo "# placeholder" > /boot/grub/grub.cfg
echo "--- PATH=$PATH"
DEB_MAINT_PARAMS="configure " sh -x /etc/kernel/postinst.d/zz-update-grub 7.0.0-38-generic /boot/vmlinuz-7.0.0-38-generic
echo "rc=$?"
echo "--- as dpkg would: env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin"
env -i PATH=/usr/sbin:/usr/bin:/sbin:/bin DEB_MAINT_PARAMS="configure " sh -x /etc/kernel/postinst.d/zz-update-grub 7.0.0-38-generic /boot/vmlinuz-7.0.0-38-generic
echo "rc=$?"
which systemd-detect-virt
