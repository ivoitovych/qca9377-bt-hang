#!/bin/bash
# extra-line.sh <line> :
#  1. tree check: the tree this work applies (tip + patch, drivers/bluetooth only) against the tree of a real
#     cherry-pick (git merge-tree --write-tree --merge-base=888176e9a640^ <tip> 888176e9a640); empty diff = same.
#  2. W=1 build of drivers/bluetooth/ with CONFIG_PM disabled, tip and tip + 1/3 (no debug code), separate
#     object directory build/kobj-<line>-nopm (x86_64 defconfig + BT/USB/BT_HCIBTUSB, PM and its dependents off).
# Results: logs/extra/ ; summary lines on stdout.
set -u
w=${CO43_WORK}
t=$w/wt-stable
l=${1:?usage}
tip=$("$w/scripts/tip-of.sh" "$l") || exit 2
mkdir -p "$w/logs/extra"
git -C "$t" checkout -q -f "$tip" || exit 2
f=btusb.c
patch=$w/stable/patch/0001-1of3-btusb.patch
if [ -e "$t/drivers/bluetooth/btusb_main.c" ]; then
	f=btusb_main.c
	patch=$w/stable/patch/0001-1of3-btusb_main.patch
fi
f=drivers/bluetooth/$f

# 1. tree check
tree=$(git -C "$t" merge-tree --write-tree --merge-base=888176e9a640^ "$tip" 888176e9a640 2>"$w/logs/extra/merge-tree-$l.err")
echo "merge-tree rc=$? tree=$tree"
git -C "$t" apply "$patch" || exit 2
git -C "$t" diff "$tree" -- drivers/bluetooth >"$w/logs/extra/tree-diff-$l.txt" 2>&1
echo "tree check $l: diff bytes vs cherry-pick tree (drivers/bluetooth): $(wc -c <"$w/logs/extra/tree-diff-$l.txt")"
git -C "$t" checkout -q -f "$tip"

# 2. CONFIG_PM off
obj=$w/build/kobj-$l-nopm
mkdir -p "$obj"
if [ ! -e "$obj/.config" ]; then
	nice -n 19 ionice -c 3 make -C "$t" O="$obj" ARCH=x86_64 defconfig >"$w/logs/extra/nopm-config-$l.log" 2>&1 || exit 1
	c=$t/scripts/config
	"$c" --file "$obj/.config" -d PM -d SUSPEND -d HIBERNATION -d PM_SLEEP -d ACPI -d PM_AUTOSLEEP -d PM_WAKELOCKS -d APM -e BT -e BT_HCIBTUSB -e BT_HCIBTUSB_AUTOSUSPEND -e USB -e USB_SUPPORT -e NET -e BT_BREDR -e USB_EHCI_HCD
	nice -n 19 ionice -c 3 make -C "$t" O="$obj" ARCH=x86_64 olddefconfig >>"$w/logs/extra/nopm-config-$l.log" 2>&1 || exit 1
fi
echo "nopm config $l: $(grep -E '^(CONFIG_PM=|# CONFIG_PM is not set|CONFIG_BT_HCIBTUSB=|CONFIG_BT_HCIBTUSB_AUTOSUSPEND=|CONFIG_USB=)' "$obj/.config" | tr '\n' ' ')"
for v in base p1; do
	git -C "$t" checkout -q -f "$tip" || exit 2
	[ "$v" = p1 ] && { git -C "$t" apply "$patch" || exit 2; }
	touch "$t/$f"
	nice -n 19 ionice -c 3 make -C "$t" O="$obj" ARCH=x86_64 -j12 W=1 drivers/bluetooth/ >"$w/logs/extra/w1-nopm-$l-$v.log" 2>&1
	echo "W1-NOPM $l $v rc=$? btusb warnings: $(grep -c 'btusb.*warning' "$w/logs/extra/w1-nopm-$l-$v.log") btusb.o built: $(grep -c 'btusb' "$w/logs/extra/w1-nopm-$l-$v.log")"
done
git -C "$t" checkout -q -f "$tip"
echo EXTRA-LINE-DONE "$l"
