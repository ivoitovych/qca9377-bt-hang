#!/bin/bash
# asus.sh <tag> : in its own worktree, cherry-pick -x d54601f21faf then cfa67a1dbfd9 onto the stable tag, log it,
# build drivers/bluetooth/btusb.o (x86_64 defconfig + BT=m, BT_HCIBTUSB=m, W=1) on the tag and on tag + pair, compare warnings.
set -u
TAG=${1:?usage}
W=/root/exp/agent-work/lane5-status-stable-20261114/co22
KR=/root/exp/agent-work/lane5-status-stable-20261114/k/repo
T=/root/exp/agent-work/lane5-status-stable-20261114/k/wt22-$TAG
L=$W/logs
mkdir -p "$L"
C1=d54601f21faf1ab5728e98e2102c3f738be0c177
C2=cfa67a1dbfd9425044f6eef037a114b2d108f436
if [[ ! -e $T ]]; then git -C "$KR" worktree add --detach "$T" "$TAG" > /dev/null || exit 2; fi
git -C "$T" reset -q --hard "$TAG" || exit 2
git -C "$T" clean -q -fdx
{
	echo "tag $TAG commit $(git -C "$T" rev-parse HEAD)"
	echo "btusb.c has 0b05:1825: $(grep -c '0x0b05, 0x1825' "$T/drivers/bluetooth/btusb.c")  0b05:1868: $(grep -c '0x0b05, 0x1868' "$T/drivers/bluetooth/btusb.c")"
} > "$L/pick-$TAG.log"
cfg() {
	cd "$T" || exit 2
	make ARCH=x86 x86_64_defconfig > /dev/null 2>&1
	scripts/config -m BT -m BT_HCIBTUSB -e BT_BREDR -e BT_LE -e USB -e USB_SUPPORT -e NET -e INET -e RFKILL
	[[ -n ${NOWERROR:-} ]] && scripts/config -d WERROR
	make ARCH=x86 olddefconfig > /dev/null 2>&1
	make ARCH=x86 -j4 prepare > "$L/prepare-$TAG.log" 2>&1 || { echo "prepare failed" >> "$L/pick-$TAG.log"; return 1; }
}
objb() { # label
	cd "$T" || exit 2
	rm -f drivers/bluetooth/btusb.o
	make ARCH=x86 W=1 drivers/bluetooth/btusb.o > "$L/build-btusb-$TAG-$1.log" 2>&1
	echo "$1 btusb.o rc=$? warnings: $(grep -c -a 'warning:' "$L/build-btusb-$TAG-$1.log")" >> "$L/pick-$TAG.log"
}
cfg || exit 1
objb base
git -C "$T" -c user.name=check -c user.email=check@example.com cherry-pick -x "$C1" "$C2" >> "$L/pick-$TAG.log" 2>&1
echo "cherry-pick rc=$?" >> "$L/pick-$TAG.log"
git -C "$T" log --format='%h %s' -n 3 >> "$L/pick-$TAG.log"
git -C "$T" diff --stat "$TAG" >> "$L/pick-$TAG.log"
objb pair
echo "btusb.c now has 0b05:1825: $(grep -c '0x0b05, 0x1825' "$T/drivers/bluetooth/btusb.c")  0b05:1868: $(grep -c '0x0b05, 0x1868' "$T/drivers/bluetooth/btusb.c")" >> "$L/pick-$TAG.log"
echo "new warnings (lines in pair log not in base log):" >> "$L/pick-$TAG.log"
diff <(grep -a 'warning:' "$L/build-btusb-$TAG-base.log" | sed 's/:[0-9]*:[0-9]*:/:/') <(grep -a 'warning:' "$L/build-btusb-$TAG-pair.log" | sed 's/:[0-9]*:[0-9]*:/:/') >> "$L/pick-$TAG.log" 2>&1
echo "diff rc=$? (0 = identical warning sets)" >> "$L/pick-$TAG.log"
echo "ASUS-DONE $TAG" >> "$L/pick-$TAG.log"
