#!/bin/bash
# run-bot.sh: the linux-bluetooth CI bot's checks (the project's scripts/bot-ci-local.sh, run from
# this work directory's clone of the project, docker limited to 6 CPUs), on bluetooth-next
# da3cc02587c6: E alone on both sides (patched and base), then A alone, patched side (its base side is
# the same commit as E's). Outputs in project/tmp/bot-ci-local/{E,A}-20261113/.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
p=$w/project
base=da3cc02587c629420603df4395179ec82955c941
bluez=20ffd285b58facfd1f2478d159a5f941b09d5be1
"$p/scripts/bot-ci-local.sh" --tree "$w/linux" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/E-20261113" --side both \
	"$w/package/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch"
echo "E exit $?"
"$p/scripts/bot-ci-local.sh" --tree "$w/linux" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/A-20261113" --side patched \
	"$w/package/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch"
echo "A exit $?"
