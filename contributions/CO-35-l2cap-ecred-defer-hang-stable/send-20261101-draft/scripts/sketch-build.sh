#!/bin/bash
# sketch-build.sh : v7.3.1 + 5874f8d03268 + drafts/sketch-ecred-only-v7.3.1.diff (the ECRED-only stable-specific sketch)
set -u
TAG=v7.3.1
W=/root/exp/agent-work/co35/refresh-20261101
T=$W/wt/$TAG
exec >> "$W/logs/driver-sketch.log" 2>&1
say() { echo "$(date -u '+%F %T') UTC build sketch: $*" | tee -a "$W/progress.log"; }
cd "$T" || exit 2
git reset -q --hard "$TAG"
git cherry-pick --no-commit 5874f8d03268 || { say "sci cherry-pick failed"; exit 1; }
git apply "$W/drafts/sketch-ecred-only-v7.3.1.diff" || { say "sketch apply failed"; exit 1; }
say "make start"
make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-sketch.log" 2>&1 || { say "olddefconfig failed"; exit 1; }
make ARCH=x86 -j4 > "$W/logs/build-sketch.log" 2>&1
rc=$?
say "make rc=$rc"
[[ $rc -eq 0 ]] || exit 1
cp arch/x86/boot/bzImage "$W/img/bzImage-$TAG-sci-sketch"
git diff HEAD --stat > "$W/img/bzImage-$TAG-sci-sketch.commit"
grep -a -E "warning:" "$W/logs/build-sketch.log" | grep -a -E "net/bluetooth" > "$W/logs/btwarn-sketch.log"
say "done"
