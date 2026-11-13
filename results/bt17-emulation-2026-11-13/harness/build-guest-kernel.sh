#!/bin/bash
# build-guest-kernel.sh <tag>
# Builds the BT-17 guest kernel from the worktree ../linux (whatever patches are applied
# now) into build/kobj (incremental), copies the image to img/bzImage-<tag>, the config to
# img/config-<tag>, and records HEAD and the modified files in img/bzImage-<tag>.commit.
set -u
w=/root/exp/agent-work/bt17-emu-20261113
t=$w/linux
obj=$w/build/kobj
tag=${1:?usage}
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/co20-diag-20261101/img/config-base "$obj/.config" || exit 2
	cat "$w/scripts/frag-bt17.config" >>"$obj/.config"
fi
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j14 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" status --short
	git -C "$t" diff --stat
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|BT_HCIBTUSB_AUTOSUSPEND|USBIP_VHCI_HCD|USB_MON|USB_DUMMY_HCD|USB_RAW_GADGET)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
