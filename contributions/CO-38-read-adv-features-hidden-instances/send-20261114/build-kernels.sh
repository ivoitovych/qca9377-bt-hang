#!/bin/bash
# build-kernels.sh - the two guest kernels for CO-38: plain bluetooth-next tip and tip + fix.
# Config = the 2026-11-02 config (doc/tester.config + SMP fragment + KASAN + lockdep), olddefconfig.
# Out of tree in $W/build/kasan-co38; images in CO-38/img/. -j4.
set -u
ulimit -c 0
W=/root/exp/agent-work/lane3-mgmt-20261114
T=$W/kernel
O=$W/build/kasan-co38
I=$W/CO-38/img
CFG=/root/exp/agent-work/co38-ready-20261102/img/config-plain
avail=$(df --output=avail -BG /root/exp | tail -n 1 | tr -dc '0-9')
if [ "$avail" -lt 25 ]; then
	echo "only ${avail} GB free, refusing"
	exit 3
fi
mkdir -p "$I" "$O"
[ -e "$O/.config" ] || cp "$CFG" "$O/.config"
for pair in "plain tip-next" "fix co38-next"; do
	set -- $pair
	TAG=$1
	BR=$2
	git -C "$T" checkout -q "$BR" || exit 2
	date +%H:%M:%S > "$I/build-$TAG.start"
	make -C "$T" O="$O" olddefconfig > "$I/olddefconfig-$TAG.log" 2>&1
	nice -n 10 make -C "$T" O="$O" -j4 > "$I/build-$TAG.log" 2>&1
	rc=$?
	date +%H:%M:%S > "$I/build-$TAG.end"
	echo "build $TAG rc=$rc"
	tail -n 3 "$I/build-$TAG.log"
	[ "$rc" = 0 ] || exit $rc
	cp "$O/arch/x86/boot/bzImage" "$I/bzImage-$TAG"
	cp "$O/.config" "$I/config-$TAG"
	git -C "$T" log -2 --format='%H %s' > "$I/commit-$TAG"
	git -C "$T" status --short >> "$I/commit-$TAG"
	sha256sum "$I/bzImage-$TAG"
done
grep -E '^(# )?CONFIG_(KASAN|PROVE_LOCKING|SMP|BT|BT_LE)[= ]' "$O/.config"
