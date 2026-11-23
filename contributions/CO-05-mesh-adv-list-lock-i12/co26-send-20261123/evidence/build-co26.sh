#!/bin/bash
# build-co26.sh : CO-26 on the tip. Two images from bluetooth-next cf357cfc025e plus the TEST ONLY knob
# (apply-co26-knob.py): co26-base, and co26-patched = the same plus CO-26's patch.
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
T=$W/wt
P26=$R/contributions/CO-05-mesh-adv-list-lock-i12/review-fixes-20261114/variant-A-with-fixes/0002-Bluetooth-MGMT-Stop-mesh_send_sync-when-it-cannot-ad.patch
CFG=$R/cache/co02-w2c-bluez/doc/tester.config
HT=${KQ_HUNGTASK:?set KQ_HUNGTASK to a config fragment enabling hung-task detection}
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
mk() { # <variant>
	nice -n 19 ionice -c 3 make -C "$T" ARCH=x86 -j12 > "$W/logs/build-co26-$1.log" 2>&1
	local rc=$?; say "co26 $1 make rc=$rc"; [[ $rc -eq 0 ]] || return 1
	cp "$T/arch/x86/boot/bzImage" "$W/img/bzImage-co26-$1"
	{ git -C "$T" log -n 1 --format='base %H %s'; git -C "$T" diff HEAD --stat; } > "$W/img/bzImage-co26-$1.commit"
	return 0
}
git -C "$T" checkout -q --detach -f cf357cfc025e || exit 2
cp "$CFG" "$T/.config"; cat "$HT" "$R/tmp/kernel-queue-20261123/kprobes.config" >> "$T/.config"
make -C "$T" ARCH=x86 olddefconfig > "$W/logs/olddefconfig-co26.log" 2>&1 || exit 1
python3 -I "$R/tmp/kernel-queue-20261123/apply-co26-knob.py" "$T" || exit 1
mk base || exit 1
git -C "$T" apply "$P26" || { say "co26 apply failed"; exit 1; }
mk patched || exit 1
git -C "$T" checkout -q -f co43-series-20261123
say "co26 builds done"
