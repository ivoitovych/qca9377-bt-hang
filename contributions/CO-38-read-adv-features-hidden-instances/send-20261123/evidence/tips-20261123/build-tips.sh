#!/bin/bash
# build-tips.sh : CO-38 + CO-44 on every tree at its current tip (2026-11-23 evening): bluetooth-next, mainline,
# and the five stable lines both patches reach (their Fixes: commits are in 7.3..6.1, not 5.15/5.10).
# Per tree: base and base + both patches, BlueZ doc/tester.config + hung-task detection, one reused worktree.
# Writes img/bzImage-<tree>-{base,patched} and, for the manifest, img/<image>.versions (tree commit, applied
# patch-ids, .config SHA-256, compiler, binutils). Logs in $W2/logs. Low priority, one build at a time.
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
W2=$W/tips2
T=$W/wt
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=${KQ_HUNGTASK:?set KQ_HUNGTASK to a config fragment enabling hung-task detection}
P38=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch
P44=$R/contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261123/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
mkdir -p "$W2/img" "$W2/logs"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
versions() { # <image>
	{
		echo "tree $(git -C "$T" log -n 1 --format='%H %s' HEAD)"
		git -C "$T" diff HEAD --stat
		for p in "$@"; do echo "patch-id $(git -C "$T" patch-id --stable < "$p") $(basename "$p")"; done
		echo "config-sha256 $(sha256sum "$T/.config" | cut -d' ' -f1)"
		echo "config-fragments $(sha256sum "$CFG" | cut -c1-16) tester.config, $(sha256sum "$HT" | cut -c1-16) hungtask.config"
		echo "compiler $(gcc --version | head -n 1)"
		echo "binutils $(ld --version | head -n 1)"
	} > "$W2/img/$1.versions"
}
build() { # <tree> <variant> [patch...]
	local n=$1 v=$2; shift 2
	make -C "$T" ARCH=x86 olddefconfig > "$W2/logs/olddefconfig-$n-$v.log" 2>&1 || { say "tips $n $v olddefconfig failed"; return 1; }
	nice -n 19 ionice -c 3 make -C "$T" ARCH=x86 -j12 > "$W2/logs/build-$n-$v.log" 2>&1
	local rc=$?; say "tips $n $v make rc=$rc"
	[[ $rc -eq 0 ]] || return 1
	cp "$T/arch/x86/boot/bzImage" "$W2/img/bzImage-$n-$v"
	versions "bzImage-$n-$v" "$@"
	return 0
}
# Variants (2026-11-23, after an outside recheck): each patch is sent alone, CO-38 days before CO-44, so each is
# tested alone: base, base + CO-38 only ("co38"), base + CO-44 only ("co44"). The joint "patched" images of the
# first pass are kept, not used for the testing notes.
for spec in next:bluetooth-next/master main:origin/master 7.3:stable/linux-7.3.y 6.18:stable/linux-6.18.y \
	6.12:stable/linux-6.12.y 6.6:stable/linux-6.6.y 6.1:stable/linux-6.1.y; do
	n=${spec%%:*}; rev=${spec#*:}
	if [[ -e $W2/img/bzImage-$n-co38 && -e $W2/img/bzImage-$n-co44 ]]; then say "tips $n already built"; continue; fi
	git -C "$T" checkout -q --detach -f "$rev" || { say "tips $n checkout failed"; continue; }
	git -C "$T" clean -q -fdx -e .config
	cp "$CFG" "$T/.config"; cat "$HT" >> "$T/.config"
	if [[ ! -e $W2/img/bzImage-$n-base ]]; then build "$n" base || continue; fi
	for vp in co38:$P38 co44:$P44; do
		v=${vp%%:*}; p=${vp#*:}
		[[ -e $W2/img/bzImage-$n-$v ]] && continue
		git -C "$T" checkout -q -f "$rev"
		git -C "$T" apply "$p" || { say "tips $n $v apply failed"; continue; }
		build "$n" "$v" "$p" || continue
	done
	git -C "$T" checkout -q -f "$rev"
done
git -C "$T" checkout -q -f co43-series-20261123
say "tips builds done"
