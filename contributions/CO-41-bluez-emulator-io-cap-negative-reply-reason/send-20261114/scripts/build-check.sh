#!/bin/sh
# Build (same configure line as CO-39's package) and make check of co41/work-patched in the noble build container.
# Log: logs/build-check-patched.log
set -u
top=/root/exp/agent-work/lane4-bluez-20261114/co41
conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
echo "configure line: $conf" > "$top/logs/build-check-patched.log"
docker run --rm --name lane4-co41-buildcheck -v "$top/work-patched:/b" -w /b co03-noble-build:1 sh -c "
make distclean >/dev/null 2>&1
if [ ! -x ./configure ] || [ ! -f Makefile.in ]; then ./bootstrap || exit 1; fi
$conf && make -j4 && make -j4 check
echo \"make exit \$?\"" >> "$top/logs/build-check-patched.log" 2>&1
tail -30 "$top/logs/build-check-patched.log"
