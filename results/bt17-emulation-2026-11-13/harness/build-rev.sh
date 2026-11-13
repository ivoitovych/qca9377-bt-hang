#!/bin/bash
# build-rev.sh <tag> <rev> [<obj dir name> [<config fragment file>]]
# Checks <rev> out (detached) in the worktree linux/, builds into build/<obj dir name>
# (default kobj; a missing one is seeded by copying kobj, so the build stays incremental),
# copies the image to img/bzImage-<tag> and the config to img/config-<tag>, and records HEAD,
# status, diff stat and key config in img/bzImage-<tag>.commit. Refuses to overwrite an image.
set -u
w=/root/exp/agent-work/bt17-emu-20261113
t=$w/linux
tag=${1:?usage}
rev=${2:?usage}
objname=${3:-kobj}
frag=${4:-}
obj=$w/build/$objname
[ -e "$w/img/bzImage-$tag" ] && { echo "exists: img/bzImage-$tag"; exit 2; }
[ -d "$obj" ] || cp -a "$w/build/kobj" "$obj" || exit 2
if [ -n "$frag" ]; then
	cat "$frag" >>"$obj/.config" || exit 2
fi
git -C "$t" checkout -q --detach "$rev" || exit 2
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j14 bzImage
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
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|USB_MON|USB_DUMMY_HCD|USB_RAW_GADGET|DEBUG_KMEMLEAK[A-Z_]*)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
