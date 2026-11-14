#!/bin/sh
# Interleaved: master (unpatched build) and patched, 7 runs each, test_device.py only.
top=/root/exp/agent-work/lane4-bluez-20261114/co39
for n in 0 1 2 3 4 5 6; do
    "$top/scripts/run-c.sh" master-base "$n" test_device.py
    "$top/scripts/run-c.sh" master-patched "$n" test_device.py
done
