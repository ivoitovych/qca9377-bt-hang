#!/bin/bash
# exit-build.sh master | 572 <name> <tree-dir>
#   master : master 14bd6ab65 (from the project's upstream clone) built as CO-37 did (bot image, ASan+UBSan); its tools are
#            copied into the 5.72 trees.
#   572    : copy <tree-dir> (an unpacked, patched Ubuntu source tree), add master's functional harness (CO-37's
#            "local: add master's functional test harness to 5.72", 0049), configure with ASan/UBSan, make with -Wno-error
#            (5.72 does not build under -Werror with the image's compiler), then put master's btvirt, bluetoothctl, btmgmt and
#            test-runner in place of 5.72's (5.72's kept as *.5.72).
set -u
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
W=$B/exit
IMG=bluez-action-ci:60348956fc7b
UP=/root/exp/qca9377-bt-hang/cache/bluez-upstream
ELLUP=/root/exp/qca9377-bt-hang/cache/ell
HARNESS=/root/exp/agent-work/exit-uaf/saved-before-cleanup/repo/local-commits/0049-local-add-master-s-functional-test-harness-to-5.72.patch
mkdir -p "$W"
log() { echo "$(date -u '+%F %T') UTC exit-build: $*" | tee -a "$B/logs/progress.log"; }
run_docker() { docker run --rm --volume "$W:$W" --workdir "$d/src" "$@"; }
mode=$1
case $mode in
master)
	d=$W/master
	[[ -e $d ]] && { echo "refusing: $d exists"; exit 2; }
	mkdir -p "$d"
	git clone --quiet --no-checkout "$UP" "$d/src" || exit 2
	git -C "$d/src" checkout --quiet --detach 14bd6ab65 || exit 2
	git clone --quiet --no-checkout "$ELLUP" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach 002b32d7c091 || exit 2
	log "build master"
	run_docker --entrypoint bash "$IMG" -c "./bootstrap-configure --disable-lsan --enable-asan --enable-ubsan && make -j4" > "$d/build.log" 2>&1
	log "end build master exit $?"
	ls -la "$d/src/emulator/btvirt" "$d/src/client/bluetoothctl" "$d/src/tools/btmgmt" "$d/src/tools/test-runner"
	;;
572)
	name=$2; tree=$3
	d=$W/$name
	[[ -e $d ]] && { echo "refusing: $d exists"; exit 2; }
	mkdir -p "$d"
	cp -a "$tree" "$d/src" || { echo "copy failed"; exit 2; }
	git clone --quiet --no-checkout "$ELLUP" "$d/ell" || exit 2
	git -C "$d/ell" checkout --quiet --detach 002b32d7c091 || exit 2
	# the harness commit also touches client/scripts/preset-custom.bt, which the Ubuntu tarball lacks: ignore that hunk
	(cd "$d/src" && patch -p1 -f -s -r - < "$HARNESS") > "$d/harness-apply.log" 2>&1
	[[ -e $d/src/test/functional/test_a2dp.py && -e $d/src/test/functional/test_exit_discovery.py ]] || { echo "harness patch failed"; cat "$d/harness-apply.log"; exit 2; }
	log "configure+make $name"
	run_docker --entrypoint bash "$IMG" -c "make distclean >/dev/null 2>&1; ./configure --enable-debug --prefix=/usr --sysconfdir=/etc --localstatedir=/var --enable-tools --enable-testing --enable-experimental --enable-deprecated --enable-library --enable-asan --disable-lsan --enable-ubsan --disable-manpages --disable-cups --disable-obex --disable-mesh --disable-midi && make -j4 CFLAGS='-g -O2 -Wno-error'" > "$d/build.log" 2>&1
	log "end build $name exit $?"
	for f in emulator/btvirt client/bluetoothctl tools/btmgmt tools/test-runner; do
		[[ -e $d/src/$f.5.72 ]] || cp -a "$d/src/$f" "$d/src/$f.5.72"
		cp -a "$W/master/src/$f" "$d/src/$f"
		echo "$f: $(sha256sum "$d/src/$f" | cut -c1-16) from master 14bd6ab65 (5.72's kept as $f.5.72)" | tee -a "$d/commits.txt"
	done
	ls -la "$d/src/src/bluetoothd"
	;;
esac
