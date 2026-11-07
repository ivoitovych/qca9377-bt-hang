#!/bin/bash
# build-laptop-module-42.sh - the CO-02 bluetooth.ko for Ubuntu 7.0.0-42 (the next boot), built
# the way build-laptop-module-v2.sh built the -38 one, so the module carries the tested code:
#   base  co02-ubuntu42/base            Ubuntu 7.0.0-42 Bluetooth sources on v7.0
#                                       (-42 already has abd93c85c8667; STATUS, the -42 warning)
#   pre   co02-ubuntu42/with816         + 816fb1590a4c in its 6.18.y form, b108ea7ebba14 (control)
#   full  co02-ubuntu42/with816-series  + the CO-02 series commit of -38's tree, ff077afb28e81
# Checks: -42's sco.c with both upstream commits must equal -38's (the -38 and -42 sco.c differ
# exactly by abd93c85c8667); the series must change -42's files exactly as it changed -38's.
# Builds against /lib/modules/7.0.0-42-generic/build (scripts/build-bluetooth-module.sh --krel);
# builds only, installs nothing. Output: tmp/co02-hw/module42/{pre,full}/ with bluetooth.ko,
# Module.symvers, modinfo.txt, SHA256SUMS, tree.txt, and module-build-<v>.log.
set -u
R=/root/exp/qca9377-bt-hang
L=$R/cache/linux
W=$R/cache/co02-ubuntu42
U42=$R/cache/ubuntu-7.0.0-42
G38=$R/cache/co02-ubuntu38
KREL=7.0.0-42-generic
D=$R/tmp/co02-hw
mkdir -p "$D/module42"

if [[ ! -d "$W" ]]; then
	git -C "$L" worktree add -q --detach "$W" v7.0 || { echo "worktree add FAILED"; exit 1; }
	git -C "$W" sparse-checkout disable || { echo "sparse-checkout disable FAILED"; exit 1; }
fi
if ! git -C "$W" rev-parse -q --verify co02-ubuntu42/base >/dev/null; then
	git -C "$W" checkout -q -b co02-ubuntu42/base v7.0 || exit 1
	for d in net/bluetooth include/net/bluetooth; do
		rm -rf "$W/$d"; cp -r "$U42/$d" "$W/$d"
	done
	git -C "$W" add -A net/bluetooth include/net/bluetooth
	git -C "$W" commit -q -m "Ubuntu 7.0.0-42 Bluetooth sources (from cache/ubuntu-7.0.0-42) on v7.0" || exit 1
fi
for d in net/bluetooth include/net/bluetooth; do
	diff -r -q "$W/$d" "$U42/$d" >/dev/null || { echo "base $d differs from $U42"; exit 1; }
done
echo "base tree equals $U42 for net/bluetooth and include/net/bluetooth: $(git -C "$W" rev-parse --short co02-ubuntu42/base)"

if ! git -C "$W" rev-parse -q --verify co02-ubuntu42/with816 >/dev/null; then
	git -C "$W" checkout -q -b co02-ubuntu42/with816 co02-ubuntu42/base || exit 1
	git -C "$W" cherry-pick -x b108ea7ebba14 || { echo "cherry-pick of b108ea7ebba14 FAILED"; git -C "$W" cherry-pick --abort; exit 1; }
fi
if ! git -C "$W" rev-parse -q --verify co02-ubuntu42/with816-series >/dev/null; then
	git -C "$W" checkout -q -b co02-ubuntu42/with816-series co02-ubuntu42/with816 || exit 1
	git -C "$W" cherry-pick -x ff077afb28e81 || { echo "cherry-pick of the series FAILED"; git -C "$W" cherry-pick --abort; exit 1; }
fi

# Check 1: sco.c with both upstream commits, -42 against -38.
if git -C "$W" show co02-ubuntu42/with816:net/bluetooth/sco.c | cmp -s - <(git -C "$G38" show co02-ubuntu38/with816:net/bluetooth/sco.c); then
	echo "check 1: -42 with816 sco.c == -38 with816 sco.c"
else
	echo "check 1 FAILED: -42 with816 sco.c differs from -38's"; exit 1
fi
# Check 2: the series changes the same files with the same diff on both kernels.
s42=$(git -C "$W" diff co02-ubuntu42/with816 co02-ubuntu42/with816-series | git patch-id --stable | cut -d' ' -f1)
s38=$(git -C "$G38" diff co02-ubuntu38/with816 co02-ubuntu38/with816-series | git patch-id --stable | cut -d' ' -f1)
if [[ -n "$s42" && "$s42" == "$s38" ]]; then
	echo "check 2: the series' patch-id is the same on -42 and -38 ($s42)"
else
	echo "check 2 FAILED: series patch-id -42 $s42, -38 $s38"; exit 1
fi

for v in pre full; do
	case $v in pre) br=co02-ubuntu42/with816 ;; full) br=co02-ubuntu42/with816-series ;; esac
	S=$D/src42-$v
	rm -rf "$S"; mkdir -p "$S"
	git -C "$W" archive "$br" net/bluetooth include/net/bluetooth | tar -x -C "$S" || { echo "archive $br FAILED"; exit 1; }
	"$R/scripts/build-bluetooth-module.sh" --ksrc "$S" --krel "$KREL" > "$D/module42-build-$v.log" 2>&1
	rc=$?
	echo "$v: build rc=$rc ($(grep -c 'vermagic matches' "$D/module42-build-$v.log") vermagic line)"
	[[ $rc -eq 0 ]] || { tail -n 20 "$D/module42-build-$v.log"; exit 1; }
	grep -E "warning:|error:" "$D/module42-build-$v.log" && echo "$v: compiler diagnostics above"
	O=$D/module42/$v
	rm -rf "$O"; mkdir -p "$O"
	cp "$R/tmp/bt-build/net/bluetooth/bluetooth.ko" "$R/tmp/bt-build/net/bluetooth/Module.symvers" "$O/"
	cp "$D/module42-build-$v.log" "$O/module-build-$v.log"
	echo "$br $(git -C "$W" rev-parse "$br")" > "$O/tree.txt"
	modinfo "$O/bluetooth.ko" > "$O/modinfo.txt"
	(cd "$O" && sha256sum bluetooth.ko Module.symvers > SHA256SUMS)
	echo "$v: $(modinfo -F srcversion "$O/bluetooth.ko")  vermagic $(modinfo -F vermagic "$O/bluetooth.ko")"
done
echo "done: $D/module42/{pre,full} (built only; nothing installed)"
