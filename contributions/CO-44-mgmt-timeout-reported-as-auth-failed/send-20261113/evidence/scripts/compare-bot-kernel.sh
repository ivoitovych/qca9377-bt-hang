#!/bin/bash
# Step 4 of bot-ci-local.sh for the split kernel run: compare each TestRunner log, base vs patched,
# and scan all of them for kernel reports.
W=/root/exp/agent-work/co44-send-20261113
P=$W/project/tmp/bot-ci-local/co44-kernel-send-20261113/patched
B=$W/project/tmp/bot-ci-local/co44-kernel-send-20261113-base/base
O=$W/project/tmp/bot-ci-local/co44-kernel-send-20261113-base/compare-split-run.txt
{
	for t in TestRunner_mgmt-tester TestRunner_mesh-tester; do
		echo "===== $t (A = base, B = patched)"
		python3 -I $W/project/scripts/compare-tester-verdicts.py $B/$t.log $P/$t.log
		echo "exit $?"
	done
	echo "===== kernel-report-scan.py"
	python3 -I $W/project/scripts/kernel-report-scan.py $B/TestRunner_*.log $P/TestRunner_*.log
	echo "exit $?"
} > $O 2>&1
cat $O
