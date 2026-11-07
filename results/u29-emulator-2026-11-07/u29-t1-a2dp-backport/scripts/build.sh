#!/bin/sh
# build.sh <base|patched|tools>
# Clean build of src/bluez-5.72-<name> in co03-noble-build:1.
#   base, patched: the CO-03 ASan/UBSan configure line (scripts/build-asan.sh)
#   tools:         the CO-03 plain tools line (scripts/build-tools.sh); gives
#                  bluetoothctl and btmgmt for the guests
# Log: logs/build-<name>.log ; the configure line is the first line of it.
set -u
top=/root/exp/agent-work/u29-t1-a2dp-backport
name=$1
case $name in
base) dir=$top/src/bluez-5.72-base ;;
patched) dir=$top/src/bluez-5.72-patched ;;
tools) dir=$top/src/bluez-5.72-tools ;;
*) echo "bad name"; exit 2 ;;
esac
if [ "$name" = tools ]; then
  conf='./configure CFLAGS="-std=gnu17 -g -O2" --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-monitor --enable-client --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
else
  conf='./configure --enable-asan --enable-ubsan --enable-debug --disable-silent-rules --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-external-ell --enable-library --enable-monitor --enable-client --enable-udev --disable-obex --disable-cups --disable-mesh --disable-midi --disable-manpages --localstatedir=/var --sysconfdir=/etc --prefix=/usr'
fi
echo "configure: $conf" > "$top/logs/build-$name.log"
docker run --rm -v "$dir:/b" -w /b co03-noble-build:1 sh -c "
set -e
make distclean >/dev/null 2>&1 || true
$conf
make -j8
echo make-exit \$?
ls -la src/bluetoothd client/bluetoothctl tools/btmgmt
" >> "$top/logs/build-$name.log" 2>&1
echo "$name build exit $?"
tail -4 "$top/logs/build-$name.log"
