#!/bin/sh
# ASan/UBSan build of a CO-03 worktree (build/<name>) in co03-noble-build:1,
# then BlueZ's unit tests under the sanitizers (make check).
# Logs: logs/asan-build-<name>.log, logs/asan-check-<name>.log
# Usage: build-asan.sh <name> [nocheck]
set -u
top=/root/exp/agent-work/co03
name=$1
dir=$top/build/$name
docker run --rm -v "$dir:/b" -w /b co03-noble-build:1 sh -c '
set -e
if [ ! -f Makefile ]; then
  ./configure --enable-asan --enable-ubsan --enable-debug \
    --disable-silent-rules --enable-tools --enable-testing \
    --enable-experimental --enable-deprecated --enable-external-ell \
    --enable-library --enable-monitor --enable-client --enable-udev \
    --disable-obex --disable-cups --disable-mesh --disable-midi \
    --disable-manpages --localstatedir=/var --sysconfdir=/etc \
    --prefix=/usr
fi
make -j8
echo "make exit $?"
ls -la src/bluetoothd client/bluetoothctl tools/btmgmt
' > "$top/logs/asan-build-$name.log" 2>&1
echo "build exit $? ($(tail -1 "$top/logs/asan-build-$name.log"))"
if [ "${2:-}" = nocheck ]; then
    exit 0
fi
docker run --rm -v "$dir:/b" -w /b co03-noble-build:1 sh -c '
make -j8 check
echo "make check exit $?"
' > "$top/logs/asan-check-$name.log" 2>&1
echo "check: $(tail -1 "$top/logs/asan-check-$name.log")"
cp "$dir/test-suite.log" "$top/logs/asan-check-$name-test-suite.log" 2>/dev/null || true
