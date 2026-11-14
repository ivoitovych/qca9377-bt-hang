#!/bin/bash
# run-testers.sh: after the lockdep hunt, BlueZ's mesh-tester (10 cases) three times and mgmt-tester (515
# cases) once on each of tip, tip + CO-04 and tip + CO-04 + the fix; one guest at a time. The testers
# and the runner are the project's prebuilt ones (tmp/co05-w4/bin, read only here).
# Logs: logs/runs/tester-<tester>-<kernel>-<n>.log; summary: logs/summary-testers.txt (Total lines)
set -u
ulimit -c 0
l=/root/exp/agent-work/lane1-btusb-20261114
w=$l/task4
b=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
until grep -q "^batch:" "$w/logs/summary-lockdep.txt" 2>/dev/null; do sleep 20; done
out=$w/logs/summary-testers.txt
: >"$out"
run() {
	tester=$1
	kernel=$2
	n=$3
	log=$w/logs/runs/tester-$tester-$kernel-$n.log
	[ -e "$log" ] && return
	QEMU_SMP=4 timeout 900 "$b/test-runner" -q "$q" -o -m -o 2G -k "$l/img/bzImage-$kernel" -- "$b/$tester-master-4dc15be8" >"$log" 2>&1 </dev/null
	rc=$?
	tot=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E 'Total: ' | tail -n 1)
	rep=$(grep -a -c -E "possible circular locking|BUG:|WARNING:|KASAN:" "$log")
	echo "$tester $kernel $n rc=$rc kernel-report-lines=$rep $tot" >>"$out"
}
for n in 1 2 3; do
	for k in m-tip m-co04 m-fix; do
		run mesh-tester $k $n
	done
done
for k in m-tip m-co04 m-fix; do
	run mgmt-tester $k 1
done
echo "batch: done" >>"$out"
