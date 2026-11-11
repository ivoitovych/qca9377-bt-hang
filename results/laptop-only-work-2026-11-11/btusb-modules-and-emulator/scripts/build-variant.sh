#!/bin/bash
# build-variant.sh <name> [<patch> ...]
# Builds bluetooth.ko and btusb.ko for 7.0.0-42-generic from Ubuntu's 7.0.0-42
# sources (cache/ubuntu-7.0.0-42, read only) with the patches applied, at
# <work>/build/<name>/. The patches are applied at the tree root with patch -p1,
# in the order given. The tree's include/net/bluetooth comes FIRST in the include
# path (NOSTDINC_FLAGS, as co21-redesign's build-42.sh did), so a changed
# struct hci_conn is what both modules are compiled against.
# Builds only. Installs and loads nothing.
set -u
work=/root/exp/agent-work/laptop-btusb-modules-20261111
u=/root/exp/qca9377-bt-hang/cache/ubuntu-7.0.0-42
k=/lib/modules/7.0.0-42-generic/build
name="$1"
shift
t="$work/build/$name"
[ -e "$t" ] && { echo "exists: $t"; exit 2; }
mkdir -p "$t/include/net" "$t/net" "$t/drivers/bluetooth"
cp -r "$u/include/net/bluetooth" "$t/include/net/bluetooth" || exit 2
cp -r "$u/net/bluetooth" "$t/net/bluetooth" || exit 2
for f in btusb.c btintel.h btbcm.h btrtl.h btmtk.h; do
	cp "$u/drivers/bluetooth/$f" "$t/drivers/bluetooth/$f" || exit 2
done
for p in "$@"; do
	echo "== patch -p1 $p"
	patch -p1 -d "$t" -i "$p" || { echo "patch did not apply: $p"; exit 3; }
done
echo 'obj-m := btusb.o' >"$t/drivers/bluetooth/Makefile"
inc="-nostdinc -I$t/include"
echo "== bluetooth.ko (net/bluetooth), headers: $k, tree headers first"
make -C "$k" M="$t/net/bluetooth" NOSTDINC_FLAGS="$inc" modules 2>&1
rc1=$?
echo "make rc=$rc1"
echo "== btusb.ko"
make -C "$k" M="$t/drivers/bluetooth" NOSTDINC_FLAGS="$inc" modules 2>&1
rc2=$?
echo "make rc=$rc2"
echo "== include order check (the -I of the tree must be in the compile command)"
grep -c -o -- "-I$t/include" "$t/net/bluetooth/.hci_core.o.cmd"
grep -c -o -- "-I$t/include" "$t/drivers/bluetooth/.btusb.o.cmd"
ls -l "$t/net/bluetooth/bluetooth.ko" "$t/drivers/bluetooth/btusb.ko"
[ $rc1 -eq 0 ] && [ $rc2 -eq 0 ]
