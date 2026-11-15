#!/bin/bash
# Runs INSIDE the co46-build:1 container (work dir mounted at /work, worktree at /repo).
# inside-build.sh fetch      : apt source of 255.4-1ubuntu8.18, and systemd main
# inside-build.sh build V    : build variant V (a b c d e f) into /work/bins/V/
set -eu
P=/repo/patches/systemd/journal-file-scaling
cmd=$1
case $cmd in
fetch)
    mkdir -p /work/src/ubuntu && cd /work/src/ubuntu
    apt-get source --download-only systemd=255.4-1ubuntu8.18 >/dev/null
    dpkg-source -x systemd_255.4-1ubuntu8.18.dsc u >/dev/null
    ls /work/src/ubuntu
    cd /work/src
    if [ ! -d main ]; then git clone -q https://github.com/systemd/systemd.git main; fi
    cd main && git log -1 --format='%H %cd'
    ;;
build)
    v=$2
    src=/work/src/v-$v
    case $v in
    g|h) rm -rf "$src/build" ;;      # prototype trees are edited in place (h = g + boot-order cache)
    *) rm -rf "$src" ;;
    esac
    case $v in
    g|h) ;;
    a|b|c|d) cp -a /work/src/ubuntu/u "$src" ;;
    e|f) git -C /work/src/main worktree prune; git clone -q --shared /work/src/main "$src"
         git -C "$src" checkout -q "${MAIN_REV:-6bd4689}" ;;
    esac
    cd "$src"
    case $v in
    b|c|d) patch -p1 < $P/0001-*.patch; patch -p1 < $P/0002-*.patch ;;
    esac
    case $v in
    c) patch -p1 < $P/0003-*.patch; patch -p1 < $P/0004-*.patch ;;
    d) patch -p1 < $P/boot-order-cache/*-255.4.patch ;;
    f) patch -p1 < $P/boot-order-cache/*-main.patch ;;
    esac
    nice -n 19 meson setup build --buildtype=release -Dmode=release \
        -Dtests=false -Dman=disabled -Dhtml=disabled -Dtranslations=false >/work/build-$v.setup.log 2>&1 || { tail -30 /work/build-$v.setup.log; exit 1; }
    nice -n 19 ninja -C build -j6 journalctl systemd-journal-remote >/work/build-$v.log 2>&1 || { tail -30 /work/build-$v.log; exit 1; }
    mkdir -p /work/bins/$v
    cp build/journalctl build/systemd-journal-remote /work/bins/$v/
    # shared libs journalctl needs from its own build
    cp build/src/shared/libsystemd-shared-*.so /work/bins/$v/ 2>/dev/null || true
    ls -la /work/bins/$v
    ;;
esac
