#!/bin/bash
# Inside co46-build:1: does the prototype (heap patch) apply to main without the PR, and does it conflict with the PR?
cd /work/src/main
git fetch -q origin main 2>&1 | tail -2
tip=$(git rev-parse origin/main)
echo "origin/main now: $tip ($(git log -1 --format=%cd origin/main))"
P=$(ls /repo/patches/systemd/journal-file-scaling/heap/0001-*.patch)
for rev in 32d75628c4 6bd4689 $tip; do
    rm -rf /tmp/ac; git clone -q --shared /work/src/main /tmp/ac; cd /tmp/ac; git checkout -q $rev
    printf '%s: git apply --check (strict, no 3way): ' $rev
    git apply --check $P 2>&1 | head -3 | tr '\n' ' '; echo "exit ${PIPESTATUS[0]}"
    printf '%s: git apply --3way: ' $rev
    git apply --3way $P 2>&1 | tail -3 | tr '\n' ' '; echo "exit ${PIPESTATUS[0]}"
    cd /work/src/main
done
echo "--- the prototype on top of the PR head f26f6637ac"
rm -rf /tmp/ac; git clone -q --shared /work/src/main /tmp/ac; cd /tmp/ac; git checkout -q f26f6637ac
git apply --3way $P 2>&1 | tail -4
echo "conflict hunks in sd-journal.c: $(grep -c '^<<<<<<<' src/libsystemd/sd-journal/sd-journal.c)"
echo "--- the PR commit on top of the prototype (base + prototype)"
rm -rf /tmp/ac2; git clone -q --shared /work/src/main /tmp/ac2; cd /tmp/ac2; git checkout -q 32d75628c4
git apply $P
git -c user.name=x -c user.email=x@x commit -q -am proto
git -c user.name=x -c user.email=x@x cherry-pick -n f26f6637ac 2>&1 | tail -2
echo "conflict hunks in sd-journal.c: $(grep -c '^<<<<<<<' src/libsystemd/sd-journal/sd-journal.c)"
