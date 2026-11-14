#!/bin/bash
# build-ea.sh <tag> <rev>
# Checks <rev> out in this work directory's worktree linux/ (a worktree of the emulator's
# bluetooth-next repository), builds the guest kernel into build/kobj (incremental; seeded with the
# emulator's KASAN + lockdep + kmemleak config plus frag-stress.config: hung task, soft lockup and
# workqueue watchdogs), copies the image to img/bzImage-<tag> and records what it was built from in
# img/bzImage-<tag>.commit. Refuses to overwrite an image. -j8 (another build may be running).
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
t=$w/linux
obj=$w/build/kobj
tag=${1:?usage}
rev=${2:?usage}
[ -e "$w/img/bzImage-$tag" ] && { echo "exists: img/bzImage-$tag"; exit 2; }
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/bt17-emu-20261113/img/config-base-kml "$obj/.config" || exit 2
	cat "$w/scripts/frag-stress.config" >>"$obj/.config" || exit 2
fi
git -C "$t" checkout -q "$rev" || exit 2
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j8 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" log --oneline da3cc02587c629420603df4395179ec82955c941..HEAD
	git -C "$t" status --short --untracked-files=no
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DEBUG_ATOMIC_SLEEP|DETECT_HUNG_TASK|DEFAULT_HUNG_TASK_TIMEOUT|SOFTLOCKUP_DETECTOR|WQ_WATCHDOG|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|DEBUG_KMEMLEAK)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag" | tee -a "$w/img/bzImage-$tag.commit"
