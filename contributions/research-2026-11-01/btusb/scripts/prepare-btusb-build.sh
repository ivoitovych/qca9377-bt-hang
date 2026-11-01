#!/bin/bash
# prepare-btusb-build.sh <dest dir>
# Copies Ubuntu 7.0.0-42's btusb.c and the four local headers it includes into
# <dest>/orig and <dest>/patched (refuses an existing dest), and writes a
# one-line Kbuild Makefile into each. Nothing is installed or loaded.
set -eu
dest="$1"
src=/root/exp/qca9377-bt-hang/cache/ubuntu-7.0.0-42/drivers/bluetooth
[[ -e "$dest" ]] && { echo "exists: $dest" >&2; exit 2; }
for side in orig patched; do
	mkdir -p "$dest/$side"
	for f in btusb.c btintel.h btbcm.h btrtl.h btmtk.h; do
		cp "$src/$f" "$dest/$side/$f"
	done
	echo 'obj-m := btusb.o' >"$dest/$side/Makefile"
done
echo "prepared $dest (orig, patched) from $src"
