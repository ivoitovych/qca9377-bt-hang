#!/bin/bash
# run-kcsan-unreg.sh <first> <last> - KCSAN guests (tip, tip + CO-04), research mesh-tester -s UnregSweep and
# -s unregister (controller removal with sends pending), logs task3-20261114/CO-04/kcsan-logs/
W=/root/exp/agent-work/lane3-mgmt-20261114
T=$W/task3-20261114/CO-04
B=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin/mesh-tester-gates-ab927447
for n in $(seq "$1" "$2"); do
	for k in kbase kco04; do
		"$W/run-vm.sh" "$T/kcsan-logs" "UnregSweep-$k-$n" "$W/images/bzImage-$k" "$B" -s UnregSweep
		"$W/run-vm.sh" "$T/kcsan-logs" "unregister-$k-$n" "$W/images/bzImage-$k" "$B" -s unregister
	done
done
echo "$(date +%H:%M:%S) kcsan-unreg runs $1..$2 done" >> "$W/progress.log"
