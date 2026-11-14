#!/bin/bash
# run-guest.sh <kernel tag> <run label> <scenario> [emulator args...]   (task 2 copy of task 1's)
# One QEMU/KVM guest (4 CPUs) running harness/bt17-emu.py. Log: logs/runs/<tag>-<label>.log.
# Exit 0 = BT17-EXIT 0 (PASS), 1 = BT17-EXIT 1 (FAIL), 3 = no verdict (FAIL), 2 = setup error.
# Images: task 2's ../img, then task 1's lane img (same dir), then the earlier work's img.
set -u
ulimit -c 0
w=/root/exp/agent-work/lane1-btusb-20261114/task3
old=/root/exp/agent-work/bt17-emu-20261113
tr=/root/exp/agent-work/co20-diag-20261101/bin/test-runner-r3
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
tag=${1:?usage}
label=${2:?usage}
shift 2
img=$w/../img/bzImage-$tag
[ -e "$img" ] || img=$old/img/bzImage-$tag
[ -e "$img" ] || { echo "no image for $tag"; exit 2; }
mkdir -p "$w/logs/runs"
log=$w/logs/runs/$tag-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
echo "start $(date '+%F %T') kernel $tag label $label args $* cpus ${QEMU_SMP:-4}" >"$log"
sha256sum "$img" "$w/harness/bt17-emu.py" >>"$log"
timeout 300 "$tr" -q "$q" -k "$img" -- python3 -I "$w/harness/bt17-emu.py" "$@" >>"$log" 2>&1
runner_rc=$?
echo "exit=$runner_rc end $(date '+%F %T')" >>"$log"
grep -a -E "RESULT|BT17-EXIT|\] (PASS|FAIL) |EMU |MGMT (Command|Index)|command( 0x[0-9a-f]+)? tx timeout|Failed usb_autopm|Resetting usb|reset-resume|reset full-speed|USB disconnect|scenario raised|KMEMLEAK .*objects" "$log"
rc=3
verdict=$(grep -a -o -E "BT17-EXIT [01]" "$log" | tail -n 1)
[ "$verdict" = "BT17-EXIT 0" ] && rc=0
[ "$verdict" = "BT17-EXIT 1" ] && rc=1
if [ $rc -eq 0 ]; then
	echo "run-guest: $tag $label verdict=${verdict} exit=0 PASS"
else
	echo "run-guest: $tag $label verdict=${verdict:-none} exit=$rc FAIL"
fi
exit $rc
