#!/bin/sh
# Build one tree in co03-noble-build:1 (container u29t3-build-<tree>), in place.
# Usage: build.sh <master-base|master-patched|5.72-base|5.72-patched>
# Master has no configure script: ./bootstrap (autoreconf) runs first.
# Uses the image's ell (0.64, master needs >= 0.39), --enable-external-ell.
# Log: logs/build-<tree>.log
set -u
top=/root/exp/agent-work/u29-t3-lifetime-patch
t=$1
mkdir -p "$top/logs"
echo "build.sh $t start $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
echo "configure line: $conf" > "$top/logs/build-$t.log"
docker run --rm --name "u29t3-build-$t" -v "$top/work/$t:/b" -w /b co03-noble-build:1 sh -c "
make distclean >/dev/null 2>&1
if [ ! -x ./configure ] || [ ! -f Makefile.in ]; then ./bootstrap || exit 1; fi
$conf && make -j8
echo \"make exit \$?\"
ls -la src/bluetoothd emulator/btvirt tools/btmgmt monitor/btmon tools/test-runner client/bluetoothctl" \
    >> "$top/logs/build-$t.log" 2>&1
echo "build.sh $t end $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
tail -9 "$top/logs/build-$t.log"
