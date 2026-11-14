#!/bin/sh
# Base = master 20ffd285b plus only the tester change (branch co41-testonly); patched = plus the emulator fix.
# The case "Pairing Acceptor - SSP 4" must fail on the base and pass patched; every other case unchanged.
r=/root/exp/agent-work/lane4-bluez-20261114
exec "$r/project/scripts/bluez-tester-compare.sh" \
    --kernel "$r/project/tmp/kernel/bzImage-base" \
    --tree "$r/bluez" --base co41-testonly \
    --testers mgmt-tester --runs 3 --jobs 4 \
    --out "$r/co41/logs/tester-testonly-vs-fix" --label co41-testonly \
    "$r/co41/patches/0001-emulator-Use-the-reason-of-IO-Capability-Request-Neg.patch"
