#!/bin/bash
# build-bluez.sh <name> : build sco-tester, mgmt-tester, iso-tester, l2cap-tester, test-runner, btmon from lane7's
# BlueZ clone at its current checkout; copies into bin/<tool>-<name>. Low priority, make -j4.
if [[ -z "${L7_LOWPRIO:-}" ]]; then
	export L7_LOWPRIO=1
	exec nice -n 10 ionice -c 2 -n 7 "$0" "$@"
fi
set -u
W=/root/exp/agent-work/lane7-sco-20261114
B=$W/bluez
NAME=${1:?usage: build-bluez.sh <name>}
mkdir -p "$W/bin" "$W/logs"
avail_kb=$(df -Pk /root | awk 'NR==2 {print $4}')
if (( avail_kb < 25 * 1024 * 1024 )); then echo "STOP: under 25 GB free"; exit 3; fi
cd "$B" || exit 2
if ! grep -q "$W" Makefile 2>/dev/null; then
	make distclean > "$W/logs/bluez-distclean.log" 2>&1
	./bootstrap-configure > "$W/logs/bluez-configure.log" 2>&1 || { echo "configure failed"; tail -n 30 "$W/logs/bluez-configure.log"; exit 1; }
fi
make -j4 tools/sco-tester tools/l2cap-tester tools/mgmt-tester tools/iso-tester tools/test-runner monitor/btmon > "$W/logs/bluez-make-$NAME.log" 2>&1
rc=$?
echo "make rc=$rc"
grep -a -E "warning:|error:" "$W/logs/bluez-make-$NAME.log" | grep -v "^libtool" | head -n 40
[[ $rc -eq 0 ]] || exit 1
for t in sco-tester l2cap-tester mgmt-tester iso-tester test-runner; do cp tools/$t "$W/bin/$t-$NAME"; done
cmp -s monitor/btmon "$W/bin/btmon" || cp monitor/btmon "$W/bin/btmon"
git log --format='%H %s' -3 > "$W/bin/sco-tester-$NAME.base"
git diff HEAD --stat >> "$W/bin/sco-tester-$NAME.base"
sha256sum "$W/bin/"*-"$NAME" "$W/bin/btmon"
