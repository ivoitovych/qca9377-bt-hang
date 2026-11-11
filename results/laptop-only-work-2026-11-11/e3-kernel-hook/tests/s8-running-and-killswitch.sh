#!/bin/bash
# S8 (image = after S2: 38 with E3, 42 without E3, pin active): (a) the running-kernel guard: when 42
# IS the running kernel the hook must not build or touch anything of it; (b) the kill switch.
exec > /out/s8-running-and-killswitch.log 2>&1
. /w/tests/lib.sh
base_setup
export BTUSB_E3_RUNNING=7.0.0-42-generic
say "(a) 42 is the running kernel (BTUSB_E3_RUNNING); hook for 42"
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-42-generic /boot/vmlinuz-7.0.0-42-generic
echo "exit code $?"
ls -la /lib/modules/7.0.0-42-generic/updates 2>&1
cat /var/lib/btusb-e3/kernels/7.0.0-42-generic.json
export BTUSB_E3_RUNNING=7.0.0-30-generic
say "(b) kill switch"
touch /etc/btusb-e3.disabled
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-42-generic /boot/vmlinuz-7.0.0-42-generic
echo "exit code $?"
ls -la /lib/modules/7.0.0-42-generic/updates 2>&1
rm /etc/btusb-e3.disabled
say "(c) a hook that crashes internally still exits 0 and the package stays configured (BTUSB_E3_STATE points at a file, not a directory)"
touch /tmp/not-a-dir
BTUSB_E3_STATE=/tmp/not-a-dir /etc/kernel/postinst.d/50-btusb-e3 7.0.0-42-generic /boot/vmlinuz-7.0.0-42-generic
echo "exit code $?"
say "(d) missing build tools: gcc hidden (network not needed: fails before any download)"
touch /tmp/hide-gcc
mv /usr/bin/gcc /usr/bin/gcc.hidden
/etc/kernel/postinst.d/50-btusb-e3 7.0.0-42-generic /boot/vmlinuz-7.0.0-42-generic
echo "exit code $?"
mv /usr/bin/gcc.hidden /usr/bin/gcc
