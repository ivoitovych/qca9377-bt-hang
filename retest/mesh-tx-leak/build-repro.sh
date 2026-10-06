#!/bin/sh
# Build mesh-leak-check against a configured and built BlueZ tree.
# Usage: build-repro.sh <bluez-tree> [output]
set -e
BZ=${1:?bluez tree}
OUT=${2:-$BZ/tools/mesh-leak-check}
HERE=$(cd "$(dirname "$0")" && pwd)

gcc -O1 -g -Wall -Wno-unused-parameter -DHAVE_CONFIG_H \
	-I"$BZ" -I"$BZ/lib" $(pkg-config --cflags glib-2.0) \
	-o "$OUT" "$HERE/mesh-leak-check.c" \
	"$BZ/emulator/hciemu.c" "$BZ/emulator/vhci.c" "$BZ/emulator/btdev.c" \
	"$BZ/emulator/bthost.c" "$BZ/emulator/smp.c" \
	"$BZ/lib/.libs/libbluetooth-internal.a" "$BZ/src/.libs/libshared-glib.a" \
	$(pkg-config --libs glib-2.0) -lpthread
echo "built $OUT"
