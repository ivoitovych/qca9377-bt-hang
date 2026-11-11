#!/bin/bash
# build-guest-kernel.sh <tag>
# Builds the guest kernel from the working tree of linux-btnext (whatever patches are
# applied to it now) into build/kobj (incremental), copies the image to
# img/bzImage-<tag> and the config to img/config-<tag>, with the HEAD and the
# modified files recorded in img/bzImage-<tag>.commit. Builds only.
set -u
w=/root/exp/agent-work/laptop-btusb-modules-20261111
t=$w/linux-btnext
obj=$w/build/kobj
tag=${1:?usage}
mkdir -p "$obj" "$w/img"
if [ ! -e "$obj/.config" ]; then
	cp /root/exp/agent-work/co20-diag-20261101/img/config-base "$obj/.config" || exit 2
	cat "$w/scripts/frag-usbip.config" >>"$obj/.config"
fi
make -C "$t" O="$obj" ARCH=x86_64 olddefconfig || exit 1
make -C "$t" O="$obj" ARCH=x86_64 -j10 bzImage
rc=$?
echo "make rc=$rc"
[ $rc -eq 0 ] || exit 1
cp "$obj/arch/x86/boot/bzImage" "$w/img/bzImage-$tag"
cp "$obj/.config" "$w/img/config-$tag"
{
	git -C "$t" log -1 --format='%H %s'
	git -C "$t" status --short
	grep -E "^CONFIG_(SMP|NR_CPUS|KASAN|PROVE_LOCKING|DYNAMIC_DEBUG|BT_HCIBTUSB|USBIP_CORE|USBIP_VHCI_HCD)=" "$obj/.config"
} >"$w/img/bzImage-$tag.commit"
sha256sum "$w/img/bzImage-$tag"
