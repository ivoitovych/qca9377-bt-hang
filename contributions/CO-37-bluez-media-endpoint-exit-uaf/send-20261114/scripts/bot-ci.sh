#!/bin/sh
# The bot's checks (scripts/bot-ci-local.sh --space user) on master 20ffd285b + the six CO-37 mails (patches/).
# Output: project/tmp/bot-co37/
r=/root/exp/agent-work/lane4-bluez-20261114
cd "$r/project" || exit 2
m=$r/project/tmp/mail-co37
exec scripts/bot-ci-local.sh --space user \
    --base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
    --tree "$r/co37/bluez" --cache "$r/cache" \
    --kernel-image "$r/project/tmp/kernel/bzImage-base" \
    --out "$r/project/tmp/bot-co37" \
    "$m/0001-a2dp-Fix-use-after-free-when-switching-endpoints-dur.patch" \
    "$m/0002-test-Cover-A2DP-endpoint-switch-while-Close-is-pendi.patch" \
    "$m/0003-media-Fix-use-after-free-of-app-removing-a-locked-A2.patch" \
    "$m/0004-media-Fix-sending-Release-twice-to-A2DP-endpoints.patch" \
    "$m/0005-media-Fix-use-after-free-releasing-endpoints-on-adap.patch" \
    "$m/0006-test-Cover-A2DP-endpoint-release-with-an-acquired-tr.patch"
