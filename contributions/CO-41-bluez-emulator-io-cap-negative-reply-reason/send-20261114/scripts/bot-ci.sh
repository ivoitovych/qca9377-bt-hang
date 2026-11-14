#!/bin/sh
# The BlueZ CI bot's checks (scripts/bot-ci-local.sh --space user) on master 20ffd285b plus the two CO-41 patches,
# patched side first, then base. Output inside the project clone: project/tmp/bot-co41/
r=/root/exp/agent-work/lane4-bluez-20261114
cd "$r/project" || exit 2
exec scripts/bot-ci-local.sh --space user \
    --base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
    --tree "$r/bluez" --cache "$r/cache" \
    --kernel-image "$r/project/tmp/kernel/bzImage-base" \
    --out "$r/project/tmp/bot-co41-r2" \
    "$r/project/tmp/mail-co41/0001-emulator-Use-the-reason-of-IO-Capability-Request-Neg.patch" \
    "$r/project/tmp/mail-co41/0002-mgmt-tester-Check-the-status-of-Authentication-Faile.patch"
