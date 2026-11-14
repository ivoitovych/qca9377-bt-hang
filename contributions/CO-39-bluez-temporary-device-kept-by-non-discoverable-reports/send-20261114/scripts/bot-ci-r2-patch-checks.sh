#!/bin/sh
# After CheckPatch warned (LONG_LINE_COMMENT, 82 columns) on the first revision, the comment was rewrapped.
# This reruns the bot's patch-level checks on the corrected mails (patched side only): CheckPatch, GitLint.
# Output: project/tmp/bot-co39-r2/
r=/root/exp/agent-work/lane4-bluez-20261114
cd "$r/project" || exit 2
exec scripts/bot-ci-local.sh --space user --side patched --only CheckPatch,GitLint \
    --base 20ffd285b58facfd1f2478d159a5f941b09d5be1 \
    --tree "$r/bluez39" --cache "$r/cache" \
    --kernel-image "$r/project/tmp/kernel/bzImage-base" \
    --out "$r/project/tmp/bot-co39-r2" \
    "$r/project/tmp/mail-co39b/0001-adapter-Don-t-keep-temporary-devices-alive-with-non-.patch" \
    "$r/project/tmp/mail-co39b/0002-test-functional-add-test-for-temporary-device-lifeti.patch"
