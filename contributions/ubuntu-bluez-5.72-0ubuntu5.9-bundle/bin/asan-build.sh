#!/bin/bash
# ASan/UBSan builds (CO-03 / U29 configure line) of: base (5.8), bundle, sink (5.8 + the test-fixture patch; the remote),
# and a plain tools build (bluetoothctl, btmgmt for the guests); each in its own copy under asan/.
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
A=$B/asan
FIX=/root/exp/qca9377-bt-hang/contributions/CO-03-bluez-u12-backport/backport/test-fixture-patch/0001-TEST-FIXTURE-ONLY-avdtp-sink-with-a-headset-s-timing.patch
mkdir -p "$A"
say() { echo "$(date -u '+%F %T') UTC asan-build: $*" | tee -a "$B/logs/progress.log"; }
ASAN='./configure --enable-asan --enable-ubsan --enable-debug --disable-silent-rules --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-library --enable-monitor --enable-client --enable-udev --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
TOOLS='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
one() { # name source-fresh-tree configure-line
  local n=$1 src=$2 conf=$3
  [[ -e $A/$n ]] && { say "$n exists, skipping"; return; }
  say "copy $n"
  cp -a "$B/fresh/$src/bluez-5.72" "$A/$n"
  if [[ $n == sink ]]; then (cd "$A/$n" && patch -p1 < "$FIX" > "$B/logs/asan-sink-fixture.log" 2>&1) || say "FIXTURE PATCH FAILED"; fi
  say "build $n"
  echo "configure: $conf" > "$B/logs/asan-build-$n.log"
  docker run --rm -v "$A/$n:/b" -w /b co03-noble-build:1 sh -c "
make distclean >/dev/null 2>&1 || true
$conf
make -j4
echo make-exit \$?
ls -la src/bluetoothd client/bluetoothctl tools/btmgmt monitor/btmon" >> "$B/logs/asan-build-$n.log" 2>&1
  say "end $n: $(grep -c 'make-exit 0' "$B/logs/asan-build-$n.log") (1 = ok), warnings $(grep -c 'warning:' "$B/logs/asan-build-$n.log")"
}
one base base "$ASAN"
one bundle bundle "$ASAN"
one sink base "$ASAN"
one tools base "$TOOLS"
say "ASAN-BUILD-DONE"
