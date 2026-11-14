#!/bin/bash
# run-bot-co20.sh: the list bot's checks (Docker, dry run) on the two CO-20 mails, patched and base sides,
# after the CO-20 emulator batch (one guest at a time). Same local changes as run-bot-co21.sh.
set -u
w=/root/exp/agent-work/lane1-btusb-20261114/task3
l=/root/exp/agent-work/lane1-btusb-20261114
p=$w/project
base=da3cc02587c629420603df4395179ec82955c941
bluez=20ffd285b58facfd1f2478d159a5f941b09d5be1
until grep -q "^batch:" "$w/logs/summary-co20.txt" 2>/dev/null; do sleep 20; done
export BOT_PATCHED_SHARED=1
"$p/scripts/bot-ci-local.sh" --tree "$l/lx" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/co20-20261114" --side both \
	"$p/tmp/mails/0001-Bluetooth-btusb-Report-SCO-receive-failures-by-cause.patch" \
	"$p/tmp/mails/0002-Bluetooth-btusb-Log-SCO-data-for-a-just-closed-link-.patch"
echo "bot exit $?"
