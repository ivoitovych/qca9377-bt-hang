#!/bin/sh
# Build the guests' BlueZ tools (bluetoothctl, btmgmt, btmon) WITHOUT
# sanitizers, from unmodified 5.72-0ubuntu5.8, for both test images:
#   build/tools      in co03-noble-build:1
#   build-f44/tools  in co36-pw-ci:f44
# bluetoothctl 5.72 built with ASan aborts at exit (heap-use-after-free in
# client/player.c, logs/finding-bluetoothctl-5.72-exit-uaf.txt); the tests
# use it only as a tool, so it is built plain to keep its core dumps out of
# the runs. Logs: logs/tools-build-{noble,f44}.log
set -u
top=/root/exp/agent-work/co03
conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
docker run --rm -v "$top/build/tools:/b" -w /b co03-noble-build:1 sh -c "
set -e; [ -f Makefile ] || $conf; make -j8; echo \"make exit \$?\"" \
    > "$top/logs/tools-build-noble.log" 2>&1
echo "noble: $(tail -1 "$top/logs/tools-build-noble.log")"
docker run --rm -v "$top/build-f44/tools:/b" -w /b co36-pw-ci:f44 sh -c "
set -e; [ -f Makefile ] || $conf; make -j8; echo \"make exit \$?\"" \
    > "$top/logs/tools-build-f44.log" 2>&1
echo "f44: $(tail -1 "$top/logs/tools-build-f44.log")"
