#!/bin/sh
# Installed-package runs: host0 runs the packaged /usr/libexec/bluetooth/bluetoothd
# of each image (QEMU guests booted from the image's userspace):
#   R300 identity, T201 (U12 trigger, D-Bus client), T220 (normal
#   Acquire/Release control), R310 (Noble's own PipeWire/WirePlumber,
#   profile off while START is pending), three runs each,
# on the candidate image (5.72-0ubuntu5.9~ppa1) and the control image
# (archive 5.72-0ubuntu5.8).
set -u
S=/root/exp/agent-work/co03/review-20261101/scripts
"$S/log.sh" "START plan-installed"
"$S/run-l2.sh" --image co03-rev-installed:ppa1 --reps 3 /usr/libexec/bluetooth/bluetoothd inst-ppa1 \
    -k "r300 or t201 or t220 or r310" --vm-timeout 90
"$S/run-l2.sh" --image co03-rev-installed:stock --reps 3 /usr/libexec/bluetooth/bluetoothd inst-stock \
    -k "r300 or t201 or t220 or r310" --vm-timeout 90
"$S/log.sh" "END plan-installed"
