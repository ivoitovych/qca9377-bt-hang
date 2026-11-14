#!/bin/sh
# The BlueZ CI bot's checks (scripts/bot-ci-local.sh --space user) on master 20ffd285b plus the two CO-39 patches.
# Output inside the project clone: project/tmp/bot-co39/
r=/root/exp/agent-work/lane4-bluez-20261114
cd "$r/project" || exit 2
exec scripts/bot-ci-local.sh --space user \
    --base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
    --tree "$r/bluez39" --cache "$r/cache" \
    --kernel-image "$r/project/tmp/kernel/bzImage-base" \
    --out "$r/project/tmp/bot-co39" \
    "$r/project/tmp/mail-co39/0001-adapter-Don-t-keep-temporary-devices-alive-with-non-.patch" \
    "$r/project/tmp/mail-co39/0002-test-functional-add-test-for-temporary-device-lifeti.patch"
