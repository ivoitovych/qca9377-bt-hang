#!/bin/bash
# build-btusb-side.sh <dir>
# Compiles btusb.c in <dir> as an external module against the installed
# headers of 7.0.0-42 (W=1), with Ubuntu 7.0.0-42's include/ first, so the
# Bluetooth headers match the source. Builds only; never installs or loads.
set -u
dir="$1"
kbuild=/lib/modules/7.0.0-42-generic/build
inc=/root/exp/qca9377-bt-hang/cache/ubuntu-7.0.0-42/include
make -C "$kbuild" M="$dir" KCFLAGS="-I$inc" W=1 modules 2>&1
rc=$?
echo "make rc=$rc"
ls -l "$dir/btusb.ko" 2>&1
exit $rc
