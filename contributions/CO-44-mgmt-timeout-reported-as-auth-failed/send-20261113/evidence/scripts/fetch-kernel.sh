#!/bin/bash
# bluetooth-next master from its GitHub mirror (treeless, history since 2021-06-01, so the Fixes:
# target 161510ccf91c resolves), then bluetooth master from kernel.org; records the tips and checks
# them against kernel.org's ls-remote.
set -eu
W=/root/exp/agent-work/co44-send-20261113
L=$W/linux
MIRROR=https://github.com/bluez/bluetooth-next
BTNEXT=https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth-next.git
BT=https://git.kernel.org/pub/scm/linux/kernel/git/bluetooth/bluetooth.git
mkdir -p $W/logs
if [[ ! -d $L/.git ]]; then
	git clone --filter=tree:0 --shallow-since=2021-06-01 --no-checkout --branch master --origin bluetooth-next-mirror "$MIRROR" "$L"
fi
git -C $L remote get-url bluetooth > /dev/null 2>&1 || git -C $L remote add bluetooth "$BT"
git -C $L fetch --shallow-since=2026-06-01 bluetooth master
{
	date -u '+fetched %F %TZ'
	echo "kernel.org ls-remote bluetooth-next: $(git ls-remote $BTNEXT refs/heads/master)"
	echo "kernel.org ls-remote bluetooth:      $(git ls-remote $BT refs/heads/master)"
	echo "bluetooth-next (mirror) master $(git -C $L rev-parse bluetooth-next-mirror/master) $(git -C $L log -1 --format='%cI %s' bluetooth-next-mirror/master)"
	echo "bluetooth/master $(git -C $L rev-parse bluetooth/master) $(git -C $L log -1 --format='%cI %s' bluetooth/master)"
	echo "161510ccf91c: $(git -C $L log -1 --format='%h %an %s' 161510ccf91c)"
} | tee $W/logs/kernel-tips.txt
