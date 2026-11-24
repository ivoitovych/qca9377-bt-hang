#!/bin/bash
# boot-qca-lines.sh: the stock btusb's QCA setup lines of the running boot, from the kernel ring
# buffer (read-only), with the running kernel, btusb srcversion and boot id.
uname -r
cat /sys/module/btusb/srcversion
cat /proc/sys/kernel/random/boot_id
dmesg --time-format=iso | grep -E 'QCA: patch|using rampatch|using NVM|failed to request|hci0: .*(QCA|rome)'
