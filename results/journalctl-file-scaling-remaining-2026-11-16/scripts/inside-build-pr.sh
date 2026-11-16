#!/bin/bash
# Inside co46-build:1. Builds journalctl and systemd-journal-remote for variants on the PR's base:
#   e2 = main at the PR's base (32d75628c4, the parent of the PR commit)
#   p2 = e2 + PR #44579 (f26f6637ac)
#   g2 = e2 + our priority-queue prototype (patches/.../heap/0001-*), applied with git apply --3way
#   gp = p2 + the same prototype (does it still apply on top of the PR? information only)
set -u
BASE=32d75628c4
PR=f26f6637ac
for v in "$@"; do
    echo "=== $v"
    src=/work/src/v-$v
    rm -rf $src
    git clone -q --shared /work/src/main $src
    cd $src
    case $v in
    e2|g2) git checkout -q $BASE ;;
    p2|gp) git checkout -q $PR ;;
    esac
    case $v in
    g2|gp) git apply --3way /repo/patches/systemd/journal-file-scaling/heap/0001-*.patch 2>&1 | tail -8; echo "git apply exit status: ${PIPESTATUS[0]}"
           git status --short | head ;;
    esac
    nice -n 19 ionice -c 3 meson setup build --buildtype=release -Dmode=release -Dtests=false -Dman=disabled -Dhtml=disabled -Dtranslations=false > /work/build-$v.setup.log 2>&1 || { tail -20 /work/build-$v.setup.log; continue; }
    nice -n 19 ionice -c 3 ninja -C build -j6 journalctl systemd-journal-remote > /work/build-$v.log 2>&1 || { tail -30 /work/build-$v.log; continue; }
    mkdir -p /work/bins/$v
    cp build/journalctl build/systemd-journal-remote /work/bins/$v/
    cp build/src/shared/libsystemd-shared-*.so /work/bins/$v/
    ls /work/bins/$v
    git diff --stat | tail -3
done
