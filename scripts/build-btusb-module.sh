#!/bin/bash
# build-btusb-module.sh — compile ONLY btusb.ko from a Ubuntu source tree
# (scripts/prepare-ubuntu-ksrc.sh) against the RUNNING kernel's build tree,
# optionally with a patch applied first. For diagnostic btusb builds
# (e.g. E1: QCA ROME setup for 13d3:3503) loaded later via updates/ and a
# cold boot — never swapped into a live system (EX-046).
#
#   scripts/build-btusb-module.sh --ksrc cache/ubuntu-7.0.0-34 [<patch-file>]
#
# Writes only under tmp/btusb-build/. Installs and loads nothing. Prints the
# resulting module's version, srcversion and vermagic, and checks the vermagic
# against the running kernel.
#
# Only btusb.c and the four local headers it includes are compiled; the other
# Bluetooth modules it links to (btintel, btbcm, btrtl, btmtk, bluetooth) stay
# the distribution's, resolved through the kernel's Module.symvers.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC=""
if [[ "${1:-}" == "--ksrc" ]]; then SRC="${2:?--ksrc needs a directory}"; shift 2; fi
[[ -n "$SRC" ]] || { echo "usage: build-btusb-module.sh --ksrc <ubuntu tree> [<patch>]" >&2; exit 2; }
[[ "$SRC" = /* ]] || SRC="$HERE/$SRC"
PATCH="${1:-}"
OUT="$HERE/tmp/btusb-build"
KBUILD="/lib/modules/$(uname -r)/build"

[[ -r "$SRC/drivers/bluetooth/btusb.c" ]] || { echo "no $SRC/drivers/bluetooth/btusb.c" >&2; exit 2; }
[[ -d "$KBUILD" ]] || { echo "no $KBUILD — kernel headers not installed" >&2; exit 2; }
[[ -z "$PATCH" || -r "$PATCH" ]] || { echo "cannot read patch $PATCH" >&2; exit 2; }

rm -rf "$OUT"; mkdir -p "$OUT/drivers/bluetooth"
for f in btusb.c btintel.h btbcm.h btrtl.h btmtk.h; do
	cp "$SRC/drivers/bluetooth/$f" "$OUT/drivers/bluetooth/$f" || exit 2
done
echo "source: $SRC ($(git -C "$SRC" describe --tags --always 2>/dev/null) + Ubuntu diff)   headers: $KBUILD"
if [[ -n "$PATCH" ]]; then
	echo "── applying $(basename "$PATCH")"
	patch -p1 -d "$OUT" < "$PATCH" || { echo "patch did not apply" >&2; exit 1; }
fi
echo 'obj-m := btusb.o' > "$OUT/drivers/bluetooth/Makefile"

echo "── make M=drivers/bluetooth (btusb only)"
# The tree's own include/net/bluetooth headers take precedence over the
# distribution's, so the module compiles against the source it came with.
make -C "$KBUILD" M="$OUT/drivers/bluetooth" KCFLAGS="-I$SRC/include" modules 2>&1 | tail -20
rc=${PIPESTATUS[0]}
echo "── result: make rc=$rc"
KO="$OUT/drivers/bluetooth/btusb.ko"
[[ -f "$KO" ]] || exit "${rc:-1}"
modinfo -F version "$KO" | sed 's/^/   version:    /'
modinfo -F srcversion "$KO" | sed 's/^/   srcversion: /'
vm=$(modinfo -F vermagic "$KO")
echo "   vermagic:   $vm"
case "$vm" in
	"$(uname -r) "*) echo "   ✓ vermagic matches the running kernel" ;;
	*) echo "   ✗ vermagic does not match $(uname -r)"; rc=1 ;;
esac
sha256sum "$KO" | awk '{print "   sha256:     " $1}'
exit "$rc"
