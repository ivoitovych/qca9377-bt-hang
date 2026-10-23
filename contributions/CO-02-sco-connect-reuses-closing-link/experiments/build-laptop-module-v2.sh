#!/bin/bash
# build-laptop-module-v2.sh - CO-02 hardware preparation, step 2 (v2, 2026-10-23): bluetooth.ko for
# the laptop's running kernel (7.0.0-38-generic) from the SAME trees the emulator ran, so the
# module carries exactly the tested code:
#   pre   co02-ubuntu38/with816         Ubuntu 7.0.0-38 + abd93c85c8667 + 816fb1590a4c (control)
#   full  co02-ubuntu38/with816-series  the same + the CO-02 v5 series
# v1 (build-laptop-module.sh) built from cache/ubuntu-7.0.0-38 without the two commits; its
# module/series must not be installed (log.md, "the laptop's kernel").
# Checks first that co02-ubuntu38/base's Bluetooth sources equal cache/ubuntu-7.0.0-38's.
# Uses scripts/build-bluetooth-module.sh (headers in /lib/modules/<krel>/build; builds only,
# installs nothing; it writes tmp/bt-build, so the variants build one after the other).
# Output: tmp/co02-hw/module/{pre,full}/ with bluetooth.ko, Module.symvers, modinfo.txt,
# SHA256SUMS, tree.txt (branch and commit), and module-build-<v>.log.
set -u
R=/root/exp/qca9377-bt-hang
D=$R/tmp/co02-hw
G=$R/cache/co02-ubuntu38
U=$R/cache/ubuntu-7.0.0-38
B=$D/src-check-base
rm -rf "$B"; mkdir -p "$B"
git -C "$G" archive co02-ubuntu38/base net/bluetooth include/net/bluetooth | tar -x -C "$B" || { echo "archive base FAILED"; exit 1; }
for d in net/bluetooth include/net/bluetooth; do
	diff -r -q "$B/$d" "$U/$d" > "$D/src-check-$(tr / - <<<"$d").txt" || { echo "base $d differs from $U (see $D/src-check-*.txt)"; exit 1; }
done
echo "base tree equals $U for net/bluetooth and include/net/bluetooth"
for v in pre full; do
	case $v in pre) br=co02-ubuntu38/with816 ;; full) br=co02-ubuntu38/with816-series ;; esac
	S=$D/src-$v
	rm -rf "$S"; mkdir -p "$S"
	git -C "$G" archive "$br" net/bluetooth include/net/bluetooth | tar -x -C "$S" || { echo "archive $br FAILED"; exit 1; }
	"$R/scripts/build-bluetooth-module.sh" --ksrc "$S" > "$D/module-build-$v.log" 2>&1
	rc=$?
	echo "$v: build rc=$rc"
	[[ $rc -eq 0 ]] || { tail -n 20 "$D/module-build-$v.log"; exit 1; }
	grep -E "warning:|error:" "$D/module-build-$v.log" && echo "$v: compiler diagnostics above"
	O=$D/module/$v
	rm -rf "$O"; mkdir -p "$O"
	cp "$R/tmp/bt-build/net/bluetooth/bluetooth.ko" "$R/tmp/bt-build/net/bluetooth/Module.symvers" "$O/"
	echo "$br $(git -C "$G" rev-parse "$br")" > "$O/tree.txt"
	modinfo "$O/bluetooth.ko" > "$O/modinfo.txt"
	(cd "$O" && sha256sum bluetooth.ko Module.symvers > SHA256SUMS)
	grep -E "^(vermagic|srcversion):" "$O/modinfo.txt" | sed -e "s/^/$v: /"
done
