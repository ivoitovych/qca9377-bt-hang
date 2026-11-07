#!/bin/sh
# Clean rebuild of the copied laptop BlueZ 5.72 tree in co03-noble-build:1
# (plain build, no sanitizers). Source files are not changed.
# Log: logs/build.log
set -u
top=/root/exp/agent-work/u29-t2-temporary-lifetime
mkdir -p "$top/logs"
conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
echo "configure line: $conf" > "$top/logs/build.log"
docker run --rm --name u29t2-build -v "$top/src/bluez-5.72:/b" -w /b co03-noble-build:1 sh -c "
make distclean >/dev/null 2>&1; $conf && make -j8; echo \"make exit \$?\"; ls -la src/bluetoothd emulator/btvirt tools/btmgmt monitor/btmon tools/test-runner client/bluetoothctl" \
    >> "$top/logs/build.log" 2>&1
tail -8 "$top/logs/build.log"
