#!/bin/bash
# Inside co46-build:1. pg2a = base + our prototype (heap only; the PR's cache is not there, so redundant) + the PR's test.
#                      pg2b = PR head + our prototype, conflicts resolved by hand: the PR's winner/runner-up check in front of the heap.
# The tree of pg2b is /work/src/v-pgb (resolved by hand, not recreated here).
BASE=32d75628c4
PR=f26f6637ac
set -u
for v in "$@"; do
    echo "=== $v"
    case $v in
    pg2a)
        rm -rf /work/src/v-pga
        git clone -q --shared /work/src/main /work/src/v-pga
        cd /work/src/v-pga
        git checkout -q $BASE
        git apply --3way /repo/patches/systemd/journal-file-scaling/heap/0001-*.patch 2>&1 | tail -3
        git checkout $PR -- src/libsystemd/sd-journal/test-journal-interleaving.c
        src=/work/src/v-pga ;;
    pg2b) src=/work/src/v-pgb ;;
    esac
    cd $src
    rm -rf build
    nice -n 19 ionice -c 3 meson setup build --buildtype=release -Dmode=release -Dtests=false -Dman=disabled -Dhtml=disabled -Dtranslations=false > /work/build-$v.setup.log 2>&1 || { tail -20 /work/build-$v.setup.log; continue; }
    nice -n 19 ionice -c 3 ninja -C build -j4 journalctl systemd-journal-remote > /work/build-$v.log 2>&1 || { grep -E "error|FAILED" /work/build-$v.log | head -20; continue; }
    mkdir -p /work/bins/$v
    cp build/journalctl build/systemd-journal-remote /work/bins/$v/
    cp build/src/shared/libsystemd-shared-*.so /work/bins/$v/
    ls /work/bins/$v
    git diff HEAD --stat | tail -4
    git diff HEAD -- src/libsystemd > /work/proto-$v.diff
    wc -l /work/proto-$v.diff
done
