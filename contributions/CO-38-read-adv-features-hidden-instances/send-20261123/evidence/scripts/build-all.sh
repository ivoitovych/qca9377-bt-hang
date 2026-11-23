#!/bin/bash
# build-all.sh : for bluetooth-next and each live stable line, build a tester kernel (BlueZ doc/tester.config +
# hung-task detection) twice in ONE reused worktree: the base, then base + CO-38 + CO-44 (an incremental
# rebuild). Images go to $W/img/bzImage-<line>-{base,patched}. Low priority; one build at a time.
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
KR=$R/cache/linux
T=$W/wt
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=${KQ_HUNGTASK:?set KQ_HUNGTASK to a config fragment enabling hung-task detection}
P38=$R/contributions/CO-38-read-adv-features-hidden-instances/send-20261123/patch/0001-Bluetooth-MGMT-Fix-Read-Advertising-Features-hiding-.patch
P44=$R/contributions/CO-44-mgmt-timeout-reported-as-auth-failed/send-20261123/kernel/0001-Bluetooth-MGMT-Report-a-timed-out-command-as-MGMT_ST.patch
J=12
mkdir -p "$W/img" "$W/logs"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
build() { # <name> <variant>
	make -C "$T" ARCH=x86 olddefconfig > "$W/logs/olddefconfig-$1-$2.log" 2>&1 || { say "$1 $2 olddefconfig failed"; return 1; }
	nice -n 19 ionice -c 3 make -C "$T" ARCH=x86 -j"$J" > "$W/logs/build-$1-$2.log" 2>&1
	local rc=$?
	say "$1 $2 make rc=$rc"
	[[ $rc -eq 0 ]] || { grep -a -m 20 -E "error|Error" "$W/logs/build-$1-$2.log" >> "$W/progress.log"; return 1; }
	cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-$1-$2"
	{ git -C "$T" log -n 1 --format='base %H %s'; git -C "$T" diff HEAD --stat; } > "$W/img/bzImage-$1-$2.commit"
	grep -a "warning:" "$W/logs/build-$1-$2.log" | grep -a "net/bluetooth" > "$W/logs/btwarn-$1-$2.log"
	return 0   # an empty warning list is success, not a failed grep
}
if [[ ! -e $T ]]; then git -C "$KR" worktree add --detach "$T" bluetooth-next/master > "$W/logs/worktree.log" 2>&1 || { say "worktree add failed"; exit 2; }; fi
for spec in next:bluetooth-next/master 7.3:stable/linux-7.3.y 6.18:stable/linux-6.18.y 6.12:stable/linux-6.12.y 6.6:stable/linux-6.6.y 6.1:stable/linux-6.1.y; do
	name=${spec%%:*}; rev=${spec#*:}
	if [[ -e $W/img/bzImage-$name-patched ]]; then say "$name already built, skipped"; continue; fi
	say "$name checkout $rev"
	git -C "$T" checkout -q --detach -f "$rev" >> "$W/logs/checkout-$name.log" 2>&1 || { say "$name checkout failed"; continue; }
	git -C "$T" clean -q -fdx -e .config
	cp "$CFG" "$T/.config"; cat "$HT" >> "$T/.config"
	build "$name" base || continue
	git -C "$T" apply "$P38" "$P44" || { say "$name apply failed"; continue; }
	build "$name" patched || continue
	git -C "$T" checkout -q -- .
done
say "all builds done"
