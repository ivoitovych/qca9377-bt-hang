#!/bin/bash
# run-bot2.sh: as run-bot.sh, but the patched side is a --shared clone of this task's tree
# (BOT_PATCHED_SHARED=1, a local change to this clone's scripts/bot-ci-local.sh): the blobless
# bluetooth-next history clone came at a few MB per minute from kernel.org today and was stopped
# after 35 min (tmp/bot-ci-local/E-20261113 and A2-20261113 keep those partial runs).
# VerifyFixes needs the old target's history: checked separately (scripts/verifyfixes-full.sh).
# The mails are copies of the package's patch files in project/tmp/mails/ (the container sees
# only the project, the cache and the tree; E3-20261113 failed on that). The tree's common git dir
# is mounted read-only (second local change). E alone: patched and base sides; A alone: patched
# side (same base). Docker limited to 6 CPUs.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
p=$w/project
base=da3cc02587c629420603df4395179ec82955c941
bluez=20ffd285b58facfd1f2478d159a5f941b09d5be1
export BOT_PATCHED_SHARED=1
"$p/scripts/bot-ci-local.sh" --tree "$w/linux" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/E4-20261113" --side both \
	"$p/tmp/mails/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch"
echo "E exit $?"
"$p/scripts/bot-ci-local.sh" --tree "$w/linux" --base "$base" --bluez-commit "$bluez" \
	--cache "$w/cache" --out "$p/tmp/bot-ci-local/A4-20261113" --side patched \
	"$p/tmp/mails/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch"
echo "A exit $?"
