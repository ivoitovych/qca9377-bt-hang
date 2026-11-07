#!/bin/sh
# ASan/UBSan build of a CO-03 worktree (build-f44/<name>) inside PipeWire's
# CI image co36-pw-ci:f44, so PipeWire's VM tests (Fedora userspace) can run
# it as the guests' bluetoothd. Only the binaries the VM tests use.
# Log: logs/f44-build-<name>.log
# Usage: build-f44.sh <name>...
set -u
top=/root/exp/agent-work/co03
for name in "$@"; do
docker run --rm -v "$top/build-f44/$name:/b" -w /b co36-pw-ci:f44 sh -c '
set -e
if [ ! -f Makefile ]; then
  ./configure CFLAGS="-std=gnu17 -g -O2" --enable-asan --enable-ubsan \
    --enable-debug --disable-silent-rules --enable-tools --enable-testing \
    --enable-experimental --enable-deprecated --enable-external-ell \
    --enable-monitor --enable-client --disable-obex --disable-cups \
    --disable-mesh --disable-midi --disable-manpages --localstatedir=/var \
    --sysconfdir=/etc --prefix=/usr
fi
make -j8
echo "make exit $?"
ls -la src/bluetoothd client/bluetoothctl tools/btmgmt monitor/btmon
' > "$top/logs/f44-build-$name.log" 2>&1
echo "$name: exit $? ($(grep -c 'warning:' "$top/logs/f44-build-$name.log") warnings) $(grep 'make exit' "$top/logs/f44-build-$name.log")"
done
