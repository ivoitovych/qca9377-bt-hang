#!/bin/bash
# build-kernels.sh - research-sco: build tester kernels from linux-co01base, one
# revision after another in one object directory (incremental), BlueZ's
# doc/tester.config (KASAN, lockdep), optional extra fragment.
# Usage: build-kernels.sh <objdir-name> <fragment or -> <tag>=<rev> ...
# Images: img/bzImage-<tag>, img/config-<tag>, img/bzImage-<tag>.commit
set -u
W=/root/exp/agent-work/research-sco
T=$W/linux-co01base
CFG=$W/bluez-b0bf/doc/tester.config
OBJ=$W/build/${1:?usage}
FRAG=${2:?usage}
shift 2
L=$W/logs
I=$W/img
mkdir -p "$OBJ" "$L" "$I"
for pair in "$@"; do
	tag=${pair%%=*}
	rev=${pair#*=}
	echo "start $(date '+%T') build $tag at $rev"
	git -C "$T" checkout -q --detach "$rev" || { echo "checkout $rev failed"; exit 1; }
	cp "$CFG" "$OBJ/.config"
	if [[ "$FRAG" != - ]]; then cat "$FRAG" >> "$OBJ/.config"; fi
	make -C "$T" O="$OBJ" ARCH=x86_64 olddefconfig > "$L/kernel-olddefconfig-$tag.log" 2>&1 || { echo "olddefconfig failed"; exit 1; }
	make -C "$T" O="$OBJ" ARCH=x86_64 -j6 bzImage > "$L/kernel-build-$tag.log" 2>&1
	rc=$?
	echo "make rc=$rc"
	if [[ $rc -ne 0 ]]; then grep -a -E "error|Error" "$L/kernel-build-$tag.log" | tail -n 20; exit 1; fi
	cp "$OBJ/arch/x86/boot/bzImage" "$I/bzImage-$tag"
	cp "$OBJ/.config" "$I/config-$tag"
	git -C "$T" log -1 --format='%H %s' > "$I/bzImage-$tag.commit"
	grep -a -E "warning:" "$L/kernel-build-$tag.log" | grep -E "net/bluetooth" >> "$I/bzImage-$tag.commit"
	sha256sum "$I/bzImage-$tag"
	echo "end $(date '+%T') build $tag"
done
