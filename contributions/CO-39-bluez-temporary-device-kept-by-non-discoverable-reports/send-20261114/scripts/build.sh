#!/bin/sh
# Build work/<tree> in the noble build container with the configure line the earlier U29 package used.
# Usage: build.sh master-base | master-patched ; log logs/build-<tree>.log
set -u
top=/root/exp/agent-work/lane4-bluez-20261114/co39
t=$1
echo "build.sh $t start $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
echo "configure line: $conf" > "$top/logs/build-$t.log"
docker run --rm --name "lane4-co39-build-$t" -v "$top/work/$t:/b" -w /b co03-noble-build:1 sh -c "
make distclean >/dev/null 2>&1
if [ ! -x ./configure ] || [ ! -f Makefile.in ]; then ./bootstrap || exit 1; fi
$conf && make -j4
echo \"make exit \$?\"
ls -la src/bluetoothd emulator/btvirt tools/btmgmt monitor/btmon tools/test-runner client/bluetoothctl" \
    >> "$top/logs/build-$t.log" 2>&1
echo "build.sh $t end $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
tail -9 "$top/logs/build-$t.log"
