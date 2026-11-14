#!/bin/bash
# CO-03's L1 harness (transport.c with stubs, 35 tests, ASan/UBSan) against the base tree and the bundle tree
# (trees unpacked from the two source packages, configured only)
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
C=/root/exp/qca9377-bt-hang/contributions/CO-03-bluez-u12-backport/backport
S=$C/scripts/run-l1.sh
H=/root/exp/agent-work/co03/tests/l1
[[ -d $H ]] || H=$C/tests/l1
$S --verify "$C/expected/l1-base.txt" --harness "$H" "$B/fresh/base/bluez-5.72" "$B/logs/l1-base-58.log"
echo "verify base (expect 27 pass, 8 fail): exit $?"
$S --verify "$C/expected/l1-fixed.txt" --harness "$H" "$B/fresh/bundle/bluez-5.72" "$B/logs/l1-bundle.log"
echo "verify bundle (expect 35 pass): exit $?"
echo "negative control: the base judged against the fixed expectations must fail"
$S --verify "$C/expected/l1-fixed.txt" --harness "$H" "$B/fresh/base/bluez-5.72" "$B/logs/l1-base-58-judged-fixed.log"
echo "exit $? (non-zero expected)"
grep -h -E "^SUMMARY" "$B/logs/l1-base-58.log" "$B/logs/l1-bundle.log"
