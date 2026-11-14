#!/bin/bash
# apply-build.sh <name> <worktree> <base ref> <obj dir>
# On <base ref> in <worktree>: the unpatched btusb_main.o (control), then for each series (E, A,
# E then A, A then E) a detached checkout of the base, git am of the package's patch files, and
# a W=1 build of drivers/bluetooth/btusb_main.o into <obj dir> (seeded with the ea-base guest config).
# Log: build/apply-build-<name>.log; one RESULT line per series. -j8.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
name=${1:?usage}
t=${2:?usage}
base=${3:?usage}
obj=${4:?usage}
E=$w/package/E/0001-Bluetooth-btusb-Anchor-a-deferred-URB-under-txlock.patch
A=$w/package/A/0001-Bluetooth-btusb-Report-a-failed-runtime-resume-for-d.patch
log=$w/build/apply-build-$name.log
: >"$log"
mkdir -p "$obj"
[ -e "$obj/.config" ] || cp "$w/img/config-ea-base" "$obj/.config" || exit 2
git -C "$t" checkout -q --detach "$base" || exit 2
echo "== base $(git -C "$t" log -1 --format='%H %s')" >>"$log"
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig >>"$log" 2>&1 || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j8 W=1 drivers/bluetooth/btusb_main.o >>"$log" 2>&1
echo "RESULT $name unpatched build rc=$?" >>"$log"
for s in "E:$E" "A:$A" "E+A:$E $A" "A+E:$A $E"; do
	label=${s%%:*}
	files=${s#*:}
	git -C "$t" checkout -q --detach "$base" || exit 2
	# shellcheck disable=SC2086
	git -C "$t" -c user.name="Iaroslav Voitovych" -c user.email=yaroslav.voytovych@gmail.com am -q $files >>"$log" 2>&1
	amrc=$?
	if [ $amrc -ne 0 ]; then
		git -C "$t" am --abort >>"$log" 2>&1
		echo "RESULT $name $label git-am=FAIL" >>"$log"
		continue
	fi
	echo "== $label on $base: $(git -C "$t" log --oneline "$base"..HEAD | tr '\n' ';')" >>"$log"
	make -C "$t" O="$obj" ARCH=x86_64 -j8 W=1 drivers/bluetooth/btusb_main.o >"$obj/last-build.txt" 2>&1
	brc=$?
	cat "$obj/last-build.txt" >>"$log"
	nw=$(grep -c -E "warning:|error:" "$obj/last-build.txt")
	echo "RESULT $name $label git-am=OK build rc=$brc warnings_or_errors=$nw" >>"$log"
done
git -C "$t" checkout -q --detach "$base"
grep RESULT "$log"
