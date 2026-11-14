#!/bin/bash
# run-split-a.sh - the standalone BlueZ test on bluetooth-next da3cc02587c6 (plain) and + CO-38 (fix):
# the one case 3 times each, and the whole "Add" group once each. Logs task3-20261114/CO-38/logs/
W=/root/exp/agent-work/lane3-mgmt-20261114
T=$W/task3-20261114/CO-38
for n in 1 2 3; do
	for k in plain fix; do
		"$W/run-vm.sh" "$T/logs" "one-$k-$n" "$W/CO-38/img/bzImage-$k" "$T/mgmt-tester-split-a" -p "Add"
	done
done
echo "$(date +%H:%M:%S) split-a runs done" >> "$W/progress.log"
