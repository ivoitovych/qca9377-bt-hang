#!/bin/bash
# build-btusb-on.sh <new name> <existing variant> [<patch> ...]
# New btusb.ko only: copies drivers/bluetooth and include/net/bluetooth of the
# existing variant <work>/build/<variant>/ (the sources it was built from, patched
# headers included), applies the patches (patch -p1) to the copy, and builds
# btusb.ko as build-variant.sh does. The variant's bluetooth.ko is not rebuilt:
# use that one. Builds only.
set -u
work=/root/exp/agent-work/laptop-btusb-modules-20261111
k=/lib/modules/7.0.0-42-generic/build
name="$1"
from="$work/build/$2"
shift 2
t="$work/build/$name"
[ -e "$t" ] && { echo "exists: $t"; exit 2; }
mkdir -p "$t/include/net" "$t/drivers"
cp -r "$from/include/net/bluetooth" "$t/include/net/bluetooth" || exit 2
for f in btusb.c btintel.h btbcm.h btrtl.h btmtk.h Makefile; do
	mkdir -p "$t/drivers/bluetooth"
	cp "$from/drivers/bluetooth/$f" "$t/drivers/bluetooth/$f" || exit 2
done
for p in "$@"; do
	echo "== patch -p1 $p"
	patch -p1 -d "$t" -i "$p" || { echo "patch did not apply: $p"; exit 3; }
done
inc="-nostdinc -I$t/include"
make -C "$k" M="$t/drivers/bluetooth" W=1 NOSTDINC_FLAGS="$inc" modules 2>&1
rc=$?
echo "make rc=$rc"
grep -c -o -- "-I$t/include" "$t/drivers/bluetooth/.btusb.o.cmd"
ls -l "$t/drivers/bluetooth/btusb.ko"
exit $rc
