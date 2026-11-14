#!/bin/bash
# run-bot-co21.sh: the list bot's checks (project/scripts/bot-ci-local.sh, Docker, dry run) on the two
# CO-21 mails, patched and base sides. Waits for the usbip batch to end (one guest at a time).
# Local changes to the project clone's bot-ci-local.sh (each marked in it): BOT_PATCHED_SHARED, TREE
# common git dir mount, Docker --cpus (all three as in the CO-43 E package), and a read-only mount of the
# tree's alternates.
set -u
w=/root/exp/agent-work/lane1-btusb-20261114/task3
l=/root/exp/agent-work/lane1-btusb-20261114
p=$w/project
base=da3cc02587c629420603df4395179ec82955c941
bluez=20ffd285b58facfd1f2478d159a5f941b09d5be1
until grep -q "^batch:" "$w/logs/summary-co21.txt" 2>/dev/null; do sleep 20; done
export BOT_PATCHED_SHARED=1
"$p/scripts/bot-ci-local.sh" --tree "$l/lx" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/co21-20261114" --side both \
	"$p/tmp/mails/0001-Bluetooth-Keep-the-air-mode-of-SCO-links-that-came-u.patch" \
	"$p/tmp/mails/0002-Bluetooth-btusb-Pick-the-SCO-alt-setting-from-links-.patch"
echo "bot exit $?"
