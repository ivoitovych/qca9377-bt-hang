#!/bin/sh
# Whole functional suite once per build (patched tree's suite, so test_device.py is included).
top=/root/exp/agent-work/lane4-bluez-20261114/co39
"$top/scripts/run-c.sh" master-base suite .
"$top/scripts/run-c.sh" master-patched suite .
