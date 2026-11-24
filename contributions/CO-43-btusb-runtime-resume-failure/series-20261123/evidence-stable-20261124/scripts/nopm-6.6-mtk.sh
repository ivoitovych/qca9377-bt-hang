#!/bin/bash
# nopm-6.6-mtk.sh : repeat the CONFIG_PM-off W=1 build of drivers/bluetooth/ for 6.6 with BT_HCIBTUSB_MTK enabled.
# The first try (extra-line.sh) stopped on -Werror=unused-function in btmtk.h's stubs, which are unused when
# BT_HCIBTUSB_MTK is off, on the tip and with 1/3 alike. Same object directory build/kobj-6.6-nopm.
set -u
w=${CO43_WORK}
t=$w/wt-stable
l=6.6
tip=$("$w/scripts/tip-of.sh" "$l") || exit 2
obj=$w/build/kobj-$l-nopm
patch=$w/stable/patch/0001-1of3-btusb.patch
f=drivers/bluetooth/btusb.c
"$t/scripts/config" --file "$obj/.config" -e BT_HCIBTUSB_MTK -e BT_MTK
nice -n 19 ionice -c 3 make -C "$t" O="$obj" ARCH=x86_64 olddefconfig >"$w/logs/extra/nopm-mtk-config-$l.log" 2>&1 || exit 1
echo "nopm+mtk config $l: $(grep -E '^(CONFIG_PM=|# CONFIG_PM is not set|CONFIG_BT_HCIBTUSB_MTK=|CONFIG_BT_MTK=)' "$obj/.config" | tr '\n' ' ')"
for v in base p1; do
	git -C "$t" checkout -q -f "$tip" || exit 2
	[ "$v" = p1 ] && { git -C "$t" apply "$patch" || exit 2; }
	touch "$t/$f"
	nice -n 19 ionice -c 3 make -C "$t" O="$obj" ARCH=x86_64 -j12 W=1 drivers/bluetooth/ >"$w/logs/extra/w1-nopm-mtk-$l-$v.log" 2>&1
	echo "W1-NOPM-MTK $l $v rc=$? btusb warnings: $(grep -c 'btusb.*warning' "$w/logs/extra/w1-nopm-mtk-$l-$v.log") errors: $(grep -c ' error:' "$w/logs/extra/w1-nopm-mtk-$l-$v.log")"
done
git -C "$t" checkout -q -f "$tip"
echo done
