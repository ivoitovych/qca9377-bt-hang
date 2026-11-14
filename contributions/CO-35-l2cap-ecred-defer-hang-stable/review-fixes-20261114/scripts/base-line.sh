#!/bin/bash
# base-line.sh <tag>: the plain tag, same config, same runner as the reduced builds: the deferred-accept case only
# (180 s limit), to confirm in this work area that the base hangs. Tree removed before the guest starts.
set -u
TAG=${1:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
K=$W/k
T=$W/wt-base-$TAG
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=/root/exp/agent-work/co35/refresh-20261101/hungtask.config
say() { echo "$(date -u '+%F %T') UTC base $TAG: $*" | tee -a "$W/progress.log"; }
avail=$(df -B1M --output=avail /root | tail -1 | tr -d ' ')
(( avail > 27000 )) || { say "STOP: only $avail MB free"; exit 3; }
rm -rf "$T"
git -C "$K" worktree prune
git -C "$K" worktree add --detach "$T" "$TAG" > /dev/null || exit 2
cp "$CFG" "$T/.config"
cat "$HT" >> "$T/.config"
cd "$T" || exit 2
nice -n 10 ionice -c 2 -n 7 make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-$TAG-base.log" 2>&1 || { say "olddefconfig failed"; exit 1; }
say "make start"
nice -n 10 ionice -c 2 -n 7 make ARCH=x86 -j4 > "$W/logs/build-$TAG-base.log" 2>&1
rc=$?
say "make rc=$rc"
[[ $rc -eq 0 ]] || exit 1
cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-$TAG-base"
cd "$W" || exit 2
git -C "$K" worktree remove --force "$T"
say "tree removed; free $(df -B1M --output=avail /root | tail -1 | tr -d ' ') MB"
"$W/scripts/run-test.sh" "$W/img/bzImage-$TAG-base" "$W/logs/case-$TAG-base.log" 180 exact >> "$W/logs/summary-$TAG-base.txt" 2>&1
say "done"
