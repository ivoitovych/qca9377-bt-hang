#!/bin/bash
# run-bot-a.sh: the bot's checks for A alone, patched side, as in run-bot.sh, but with
# bluetooth-next history since 2026-10-01 only: A has no Fixes: tag, so VerifyFixes needs no older
# history, and kernel.org served the full 2023 clone for E at about 3 MB/min today.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
p=$w/project
base=da3cc02587c629420603df4395179ec82955c941
bluez=20ffd285b58facfd1f2478d159a5f941b09d5be1
"$p/scripts/bot-ci-local.sh" --tree "$w/linux" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/A2-20261113" --side patched --history-since 2026-10-01 \
	"$w/package/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch"
echo "A exit $?"
