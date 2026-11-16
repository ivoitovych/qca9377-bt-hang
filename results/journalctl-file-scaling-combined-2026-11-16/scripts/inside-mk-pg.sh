#!/bin/bash
# Inside co46-build:1: the combined trees, conflicts left in place for hand resolution.
#  pgb = PR head + our prototype      (git apply --3way of the prototype)
#  pga = our prototype on the base + the PR commit cherry-picked (git cherry-pick -n)
BASE=32d75628c4
PR=f26f6637ac
rm -rf /work/src/v-pgb /work/src/v-pga
git clone -q --shared /work/src/main /work/src/v-pgb
cd /work/src/v-pgb
git checkout -q $PR
git apply --3way /repo/patches/systemd/journal-file-scaling/heap/0001-*.patch 2>&1 | tail -5
echo "--- pgb status"; git status --short
grep -n '^<<<<<<<\|^=======\|^>>>>>>>' src/libsystemd/sd-journal/sd-journal.c
git clone -q --shared /work/src/main /work/src/v-pga
cd /work/src/v-pga
git checkout -q $BASE
git apply --3way /repo/patches/systemd/journal-file-scaling/heap/0001-*.patch 2>&1 | tail -3
git -c user.name=x -c user.email=x@x commit -q -am "prototype on base"
git -c user.name=x -c user.email=x@x cherry-pick -n $PR 2>&1 | tail -5
echo "--- pga status"; git status --short
grep -n '^<<<<<<<\|^=======\|^>>>>>>>' src/libsystemd/sd-journal/sd-journal.c
