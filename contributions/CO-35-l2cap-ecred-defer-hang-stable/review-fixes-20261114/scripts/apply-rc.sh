#!/bin/bash
# Do the CO-35 patches still apply on the stable-rc tips (which carry the queued patches)? Only the three files the
# patches touch are fetched (plain files of the rc branch) into a scratch directory; git apply --check, no tree needed.
# Full pair = the package's patches (7.3.y: the two mainline commits); reduced pair = ours (reduced/<line>/).
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
UA="qca9377-bt-hang/check"
RC=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git
PK=$R/contributions/CO-35-l2cap-ecred-defer-hang-stable/send-20261114/mail
exec > "$W/logs/apply-on-rc-tips.txt" 2>&1
echo "apply check started $(date -u '+%F %T') UTC"
for v in 7.3 6.18 6.12 6.6; do
	D=$W/rcscratch-$v
	rm -rf "$D"
	mkdir -p "$D/include/net/bluetooth" "$D/net/bluetooth"
	tip=$(git ls-remote "$RC" "refs/heads/linux-$v.y" | cut -c1-12)
	for f in include/net/bluetooth/l2cap.h net/bluetooth/l2cap_core.c net/bluetooth/l2cap_sock.c; do
		curl -s -A "$UA" -o "$D/$f" "$RC/plain/$f?h=linux-$v.y"
	done
	echo "== stable-rc linux-$v.y tip $tip ($(date -u '+%F %T') UTC); sizes: $(wc -c < "$D/include/net/bluetooth/l2cap.h") $(wc -c < "$D/net/bluetooth/l2cap_core.c") $(wc -c < "$D/net/bluetooth/l2cap_sock.c")"
	if [[ $v == 7.3 ]]; then
		full1=$W/upstream/608e0b7a675b.patch; full2=$W/upstream/32d86e048d8e.patch
	else
		full1=$(ls "$PK/$v.y"/0001-*.patch); full2=$(ls "$PK/$v.y"/0002-*.patch)
	fi
	red1=$(ls "$W/reduced/$v.y"/0001-*.patch); red2=$(ls "$W/reduced/$v.y"/0002-*.patch)
	for p in "full patch 1:$full1" "full patch 2:$full2" "reduced patch 1:$red1" "reduced patch 2:$red2"; do
		name=${p%%:*}; file=${p#*:}
		( cd "$D" && git apply --check "$file" ) > "$W/logs/apply-rc-$v.tmp" 2>&1 && echo "    $name: applies" || { echo "    $name: DOES NOT APPLY"; sed 's/^/        /' "$W/logs/apply-rc-$v.tmp"; }
	done
	rm -f "$W/logs/apply-rc-$v.tmp"
	rm -rf "$D"
done
echo "apply check finished $(date -u '+%F %T') UTC"
