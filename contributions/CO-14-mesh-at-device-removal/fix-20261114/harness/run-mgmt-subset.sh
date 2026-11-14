#!/bin/bash
# run-mgmt-subset.sh: a subset of BlueZ's mgmt-tester on tip + CO-04 and on tip + CO-04 + the fix: the cases
# whose names start with "Remove" (Remove UUID, Remove Device, Remove Advertising) and "Suspend". The tester's
# -s takes a prefix, and the runner passes the arguments through the kernel command line, so a prefix must be
# one word (a first attempt with "Set powered" matched every "Set" case and was stopped after 30 minutes,
# logs/runs/tester-mgmt-subset-m-co04-Set_powered.log; the full run was stopped on the tip after 217 of the 515
# cases, logs/runs/tester-mgmt-tester-m-tip-2.log, about 75 minutes per kernel).
set -u
w=/root/exp/agent-work/lane1-btusb-20261114/task4
out=$w/logs/summary-mgmt-subset.txt
: >"$out"
for k in m-co04 m-fix; do
	for p in Remove Suspend; do
		"$w/harness/run-tester-once.sh" "$k" mgmt-tester "mgmt-subset2-$k-$p" -s "$p" >>"$out"
	done
done
echo "batch: done" >>"$out"
