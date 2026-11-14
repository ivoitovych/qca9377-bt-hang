#!/bin/sh
# Confirmation after the comment rewrap: the corrected patch 1 (co39g) rebuilt in work/master-patched,
# the decisive test 3 times (runs/master-patched-r2a..c). Master runs are unchanged by the rewrap.
top=/root/exp/agent-work/lane4-bluez-20261114/co39
for n in r2a r2b r2c; do
    "$top/scripts/run-c.sh" master-patched "$n" test_device.py
done
