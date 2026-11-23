#!/bin/bash
# build-73sci.sh : 7.3.y plus the SCI fix the stable team has queued for it (5874f8d03268, BT-15), as a base
# for a full mgmt-tester run (7.3.5 alone stops at "SCI Setting"), then that plus CO-38 + CO-44.
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
T=$W/wt
P38=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch
P44=$R/contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261123/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=${KQ_HUNGTASK:?set KQ_HUNGTASK to a config fragment enabling hung-task detection}
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
mk() { # <variant>
	make -C "$T" ARCH=x86 olddefconfig > "$W/logs/olddefconfig-7.3sci-$1.log" 2>&1 || return 1
	nice -n 19 ionice -c 3 make -C "$T" ARCH=x86 -j12 > "$W/logs/build-7.3sci-$1.log" 2>&1
	local rc=$?; say "7.3sci $1 make rc=$rc"; [[ $rc -eq 0 ]] || return 1
	cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-7.3sci-$1"
	{ git -C "$T" log -n 1 --format='base %H %s'; git -C "$T" diff HEAD --stat; } > "$W/img/bzImage-7.3sci-$1.commit"
	return 0
}
git -C "$T" checkout -q --detach -f stable/linux-7.3.y || exit 2
git -C "$T" clean -q -fdx -e .config
cp "$CFG" "$T/.config"; cat "$HT" >> "$T/.config"
git -C "$T" cherry-pick --no-commit 5874f8d03268 || { say "7.3sci cherry-pick failed"; exit 1; }
mk base || exit 1
git -C "$T" apply "$P38" "$P44" || { say "7.3sci apply failed"; exit 1; }
mk patched || exit 1
git -C "$T" checkout -q -f stable/linux-7.3.y
say "7.3sci builds done"
