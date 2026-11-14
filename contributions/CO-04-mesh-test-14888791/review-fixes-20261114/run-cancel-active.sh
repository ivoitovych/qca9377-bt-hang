#!/bin/bash
# run-cancel-active.sh <first> <last> - reviewer 7's case (A running, B queued, cancel A) with the research
# mesh-tester: "Mesh - Send queue - cancel active" and its "- Ext Adv" form, images plain (tip) and co04.
# Logs task3-20261114/CO-04/logs/active-<image>-<n>.log
W=/root/exp/agent-work/lane3-mgmt-20261114
T=$W/task3-20261114/CO-04
B=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin/mesh-tester-gates-ab927447
for n in $(seq "$1" "$2"); do
	for k in plain co04; do
		img=$W/CO-38/img/bzImage-plain
		[ "$k" = co04 ] && img=$W/images/bzImage-co04
		"$W/run-vm.sh" "$T/logs" "active-$k-$n" "$img" "$B" -s cancel
	done
done
echo "$(date +%H:%M:%S) cancel-active runs $1..$2 done" >> "$W/progress.log"
