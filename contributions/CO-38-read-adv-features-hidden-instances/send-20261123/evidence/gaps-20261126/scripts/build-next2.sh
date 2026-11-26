#!/bin/bash
# build-next2.sh : CO-38 on the new bluetooth-next tip (2026-11-26), the same way as
# tmp/kernel-queue-20261123/build-tips.sh: BlueZ doc/tester.config + hung-task detection, base and base + CO-38
# only. Writes $W3/img/bzImage-next2-{base,co38} and their .versions. One build at a time, low priority.
# The shared worktree is put back on the branch it was on.
set -u
R=/root/exp/qca9377-bt-hang
W=<work area>
W3=$W/tips3
T=$W/wt
REV=f57f78086ab5
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=<work area>/refresh-20261101/hungtask.config
P38=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch
mkdir -p "$W3/img" "$W3/logs"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W3/progress.log"; }
versions() { # <image> [patch...]
	local img=$1; shift
	{
		echo "tree $(git -C "$T" log -n 1 --format='%H %s' HEAD)"
		git -C "$T" diff HEAD --stat
		for p in "$@"; do echo "patch-id $(git -C "$T" patch-id --stable < "$p") $(basename "$p")"; done
		echo "config-sha256 $(sha256sum "$T/.config" | cut -d' ' -f1)"
		echo "config-fragments $(sha256sum "$CFG" | cut -c1-16) tester.config, $(sha256sum "$HT" | cut -c1-16) hungtask.config"
		echo "compiler $(gcc --version | head -n 1)"
		echo "binutils $(ld --version | head -n 1)"
	} > "$W3/img/$img.versions"
}
build() { # <variant> [patch...]
	local v=$1; shift
	make -C "$T" ARCH=x86 olddefconfig > "$W3/logs/olddefconfig-next2-$v.log" 2>&1 || { say "next2 $v olddefconfig failed"; return 1; }
	nice -n 19 ionice -c 3 make -C "$T" ARCH=x86 -j12 > "$W3/logs/build-next2-$v.log" 2>&1
	local rc=$?; say "next2 $v make rc=$rc"
	[[ $rc -eq 0 ]] || return 1
	cp "$T/arch/x86/boot/bzImage" "$W3/img/bzImage-next2-$v"
	versions "bzImage-next2-$v" "$@"
}
PREV=$(git -C "$T" symbolic-ref -q --short HEAD || git -C "$T" rev-parse HEAD)
say "next2 builds start on $REV (worktree was on $PREV)"
git -C "$T" checkout -q --detach -f "$REV" || { say "next2 checkout failed"; exit 1; }
git -C "$T" clean -q -fdx -e .config
cp "$CFG" "$T/.config"; cat "$HT" >> "$T/.config"
ok=1
[[ -e $W3/img/bzImage-next2-base ]] || build base || ok=0
if [[ $ok -eq 1 && ! -e $W3/img/bzImage-next2-co38 ]]; then
	git -C "$T" checkout -q -f "$REV"
	if git -C "$T" apply "$P38"; then build co38 "$P38" || ok=0; else say "next2 co38 apply failed"; ok=0; fi
fi
git -C "$T" checkout -q -f "$PREV"
[[ $ok -eq 1 ]] || { say "next2 builds FAILED"; exit 1; }
say "next2 builds done"
