#!/bin/bash
# build-kernel.sh <tag> [<rev>]
# Builds the guest kernel from the work tree ../../lx (HEAD, or <rev> checked out detached; the
# working tree is built as it is when <rev> is "worktree") into ../../build/kobj (incremental),
# with the config of the existing ab2d image, -j4. Copies the image to ../../img/bzImage-<tag>
# and the config next to it; records HEAD, status, diff stat and key config in
# img/bzImage-<tag>.commit. Refuses to overwrite an image.
set -u
w=/root/exp/agent-work/lane1-btusb-20261114
t=$w/lx
obj=$w/build/kobj
tag=${1:?usage}
rev=${2:-HEAD}
[ -e "$w/img/bzImage-$tag" ] && { echo "exists: img/bzImage-$tag"; exit 2; }
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/bt17-emu-20261113/img/config-ab2d "$obj/.config" || exit 2
fi
if [ "$rev" != worktree ] && [ "$rev" != HEAD ]; then
	git -C "$t" checkout -q --detach "$rev" || exit 2
fi
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j4 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" log --oneline da3cc0258..HEAD
	git -C "$t" status --short
	git -C "$t" diff --stat
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|USB_MON|USB_DUMMY_HCD|USB_RAW_GADGET)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
