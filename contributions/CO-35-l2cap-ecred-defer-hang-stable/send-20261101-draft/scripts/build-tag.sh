#!/bin/bash
# build-tag.sh - refresh 2026-11-01: build tester.config + hung-task kernels of a stable tag, base and
# base+package series (and, for v7.3.1, the +5874f8d03268 variants). Output: img/bzImage-<tag>-<variant>.
# Usage: build-tag.sh <tag> <line> <jobs> [extra...]
#   <line>  = 6.18.y | 6.12.y | 6.6.y (series = send/<line>/0001,0002 via git apply)
#             upstream  (series = cherry-pick --no-commit 608e0b7a675b2 32d86e048d8ef)
#   extra   = sci (also build base+5874f8d03268 and pair+5874f8d03268), dc (also pair+dc1ddc65f06d)
set -u
TAG=${1:?usage}; LINE=${2:?usage}; J=${3:?usage}; shift 3
EXTRA="$*"
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/co35/refresh-20261101
T=$W/wt/$TAG
SEND=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=$W/hungtask.config
exec >> "$W/logs/driver-build-$TAG.log" 2>&1
say() { echo "$(date -u '+%F %T') UTC $*"; echo "$(date -u '+%F %T') UTC build $TAG: $*" >> "$W/progress.log"; }

mk() { # mk <variant>
	local v=$1
	say "make $TAG-$v start"
	cd "$T" || exit 2
	make ARCH=x86 olddefconfig > "$W/logs/build-olddefconfig-$TAG-$v.log" 2>&1 || { say "olddefconfig failed"; exit 1; }
	make ARCH=x86 -j"$J" > "$W/logs/build-$TAG-$v.log" 2>&1
	local rc=$?
	say "make $TAG-$v rc=$rc"
	[[ $rc -eq 0 ]] || { grep -a -m 20 -E "error|Error" "$W/logs/build-$TAG-$v.log"; exit 1; }
	cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-$TAG-$v"
	{ git -C "$T" log -n 1 --format='base %H %s'; git -C "$T" diff HEAD --stat; } > "$W/img/bzImage-$TAG-$v.commit"
	grep -a -E "warning:" "$W/logs/build-$TAG-$v.log" | grep -a -E "net/bluetooth" > "$W/logs/btwarn-$TAG-$v.log"
	say "make $TAG-$v done"
}
series() {
	if [[ $LINE == upstream ]]; then
		git -C "$T" cherry-pick --no-commit 608e0b7a675b2 32d86e048d8ef || { say "cherry-pick failed"; exit 1; }
	else
		git -C "$T" apply "$SEND/$LINE/0001-"*.patch "$SEND/$LINE/0002-"*.patch || { say "apply failed"; exit 1; }
	fi
}

say "start $TAG ($LINE) extra=[$EXTRA]"
if [[ ! -e $T ]]; then git -C "$R/cache/linux" worktree add --detach "$T" "$TAG" > /dev/null || exit 2; fi
git -C "$T" sparse-checkout disable
git -C "$T" reset -q --hard "$TAG" || exit 2
cp "$CFG" "$T/.config"
cat "$HT" >> "$T/.config"
mk base
git -C "$T" status --short -uno
series
mk pair
if [[ " $EXTRA " == *" sci "* ]]; then
	git -C "$T" reset -q --hard "$TAG"
	git -C "$T" cherry-pick --no-commit 5874f8d03268 || { say "sci cherry-pick failed"; exit 1; }
	mk sci
	series
	mk pair-sci
fi
if [[ " $EXTRA " == *" dc "* ]]; then
	git -C "$T" reset -q --hard "$TAG"
	series
	git -C "$T" cherry-pick --no-commit dc1ddc65f06d || { say "dc cherry-pick failed (rc=$?)"; git -C "$T" status --short -uno; exit 3; }
	mk pair-dc
fi
say "end $TAG"
