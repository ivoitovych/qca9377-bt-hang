#!/bin/bash
# bot-base-rerun.sh : the kernel bot's base side again, after its first try failed to prepare the workspace
# (2026-11-26 06:23 UTC: the --shared clone of the blobless cache/linux needed object 17b7ac3a..., which a
# promisor fetch may not supply there). Source tree this time: the patched side's own clone of bluetooth-next
# (kernel.org ignored the blob filter, so it holds full history since 2022-06-01 and the base commit).
# Waits for all-gaps.sh's final line, so it never runs beside the BlueZ bot run. Writes bot-co38-k-base/.
set -u
R=/root/exp/qca9377-bt-hang
D=$R/tmp/kernel-queue-20261126
L=<work area>/tips3/progress.log
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$L"; }
until grep -q -E 'ALL GAPS DONE|STOPPED' "$L"; do sleep 30; done
grep -q 'STOPPED' "$L" && { say "bot base rerun: not started, the batch stopped"; exit 1; }
say "bot base rerun start"
"$R/scripts/bot-ci-local.sh" --tree "$D/bot-co38-k/work/patched/src" --base f57f78086ab54f3b3122fbaeba2c842ba7bb6d00 \
	--bluez-commit 79162c1089110c896cb48118c3f7eb0db1fa0f2b --out "$D/bot-co38-k-base" --side base \
	"$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch" \
	> "$D/bot-co38-k-base.log" 2>&1
say "bot base rerun rc=$? (bot-co38-k-base.log)"
say "bot base rerun done"
