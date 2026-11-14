#!/bin/bash
# Negative control for the hook check: build mgmt-tester with the hook's test_condition_complete()
# removed, run the full mgmt-tester on the patched kernel (the new case must fail by timeout although
# the status is right), then restore the source and rebuild, and check the restored tree is clean.
set -u
W=/root/exp/agent-work/co44-send-20261113
B=$W/bluez
C=$W/controls
O=$C/control-no-condition.txt
{
	git -C $B apply $C/no-condition-complete.diff || exit 2
	git -C $B diff --stat
	make -C $B -j16 tools/mgmt-tester > $C/build-control.log 2>&1 || { echo "control build failed"; git -C $B apply -R $C/no-condition-complete.diff; exit 2; }
	cp $B/tools/mgmt-tester $C/mgmt-tester-control
	git -C $B apply -R $C/no-condition-complete.diff
	make -C $B -j16 tools/mgmt-tester > $C/build-restore.log 2>&1 || echo "restore build failed"
	echo "restored tree status (empty = clean):"
	git -C $B status --porcelain --untracked-files=no
	$B/tools/test-runner -k $W/kernels/bzImage-patched -- $C/mgmt-tester-control > $C/mgmt-full-patched-control.log 2>&1
	python3 -I $W/project/scripts/compare-tester-verdicts.py $W/logs/testers/mgmt-full-patched.log $C/mgmt-full-patched-control.log
	grep -a -n -E "Set Device Class - Timeout 1|Dropping HCI|Test condition|Timeout \(0x08\)|timed out|Timed out" $C/mgmt-full-patched-control.log
} > $O 2>&1
echo done >> $O
