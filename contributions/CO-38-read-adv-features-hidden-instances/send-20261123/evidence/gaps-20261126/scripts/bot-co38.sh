#!/bin/bash
# bot-co38.sh : the linux-bluetooth CI bot's own checks (scripts/bot-ci-local.sh) on CO-38's final mails, on the
# current tips (2026-11-26): the kernel patch on bluetooth-next f57f78086ab5, both sides; the BlueZ test on BlueZ
# master 79162c108911, both sides, TestFunctional booting the next2 base image (bluetooth-next without the fix,
# as the bot's own kernel would be). Output under tmp/kernel-queue-20261126/bot-co38-{k,bluez}/.
set -u
R=/root/exp/qca9377-bt-hang
D=$R/tmp/kernel-queue-20261126
W3=<work area>/tips3
P=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W3/progress.log"; }
KBASE=$(git -C "$R/cache/linux" rev-parse f57f78086ab5) || exit 1
BZ=$(git -C "$R/cache/bluez-upstream" rev-parse 79162c108911) || exit 1
mkdir -p "$D/img"
cp "$W3/img/bzImage-next2-base" "$D/img/bzImage-next2-base" || { say "bot: no next2 base image"; exit 1; }
say "bot kernel start"
"$R/scripts/bot-ci-local.sh" --tree "$R/cache/linux" --base "$KBASE" --bluez-commit "$BZ" --out "$D/bot-co38-k" \
	--side both --history-since 2022-06-01 "$P/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch" \
	> "$D/bot-co38-k.log" 2>&1
say "bot kernel rc=$?"
say "bot bluez start"
"$R/scripts/bot-ci-local.sh" --space user --base "$BZ" --out "$D/bot-co38-bluez" --side both \
	--kernel-image "$D/img/bzImage-next2-base" "$P/bluez/0001-mgmt-tester-Test-a-lone-advertising-instance-2.patch" \
	> "$D/bot-co38-bluez.log" 2>&1
say "bot bluez rc=$?"
say "bot done"
