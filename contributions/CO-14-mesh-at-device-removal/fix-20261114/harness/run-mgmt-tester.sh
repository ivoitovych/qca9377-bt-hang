#!/bin/bash
# run-mgmt-tester.sh: the hung-controller removal runs first, then BlueZ's mgmt-tester (515 cases) once on tip,
# tip + CO-04 and tip + CO-04 + the fix (the first attempt, with a 900 s limit, timed out on the tip: rc=124,
# kept in logs/runs/tester-mgmt-tester-m-tip-1.log; this one allows 3600 s). One guest at a time.
set -u
ulimit -c 0
l=/root/exp/agent-work/lane1-btusb-20261114
w=$l/task4
b=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
"$w/harness/run-batch.sh" "$w/harness/spec-hung.txt" "$w/logs/summary-hung.txt"
out=$w/logs/summary-mgmt-tester.txt
: >"$out"
for k in m-tip m-co04 m-fix; do
	log=$w/logs/runs/tester-mgmt-tester-$k-2.log
	[ -e "$log" ] && continue
	QEMU_SMP=4 timeout 3600 "$b/test-runner" -q "$q" -o -m -o 2G -k "$l/img/bzImage-$k" -- "$b/mgmt-tester-master-4dc15be8" >"$log" 2>&1 </dev/null
	rc=$?
	tot=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E 'Total: ' | tail -n 1)
	rep=$(grep -a -c -E "possible circular locking|BUG:|WARNING:|KASAN:" "$log")
	echo "mgmt-tester $k 2 rc=$rc kernel-report-lines=$rep $tot" >>"$out"
done
echo "batch: done" >>"$out"
