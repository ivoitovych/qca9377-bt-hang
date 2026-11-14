#!/bin/bash
# Compare base and patched verdicts per tester, scan for kernel reports, extract the new case.
set -u
W=/root/exp/agent-work/co44-send-20261113
P=$W/project/scripts
L=$W/logs/testers
O=$W/logs/testers-analysis.txt
{
	for t in mgmt-full l2cap-full smp-full; do
		echo "===== $t: compare-tester-verdicts.py base patched"
		python3 -I $P/compare-tester-verdicts.py $L/$t-base.log $L/$t-patched.log
		echo "exit $?"
		echo "----- totals"
		grep -a -H -E "^Total: " $L/$t-base.log $L/$t-patched.log
	done
	echo "===== kernel-report-scan.py (all tester logs)"
	python3 -I $P/kernel-report-scan.py $L/*.log
	echo "exit $?"
	for s in base patched; do
		echo "===== new case, $s (mgmt-full-$s.log)"
		grep -a -n -E "Set Device Class - Timeout 1|Dropping HCI command|Unexpected status|Opcode 0x0c24|command 0x0c24 tx timeout" $L/mgmt-full-$s.log
		echo "----- every hook firing in the full run"
		grep -a -c "Dropping HCI command" $L/mgmt-full-$s.log
		echo "----- Get Conn Info - Power off"
		grep -a -n -E "Get Conn Info - Power off|Unexpected status got" $L/mgmt-full-$s.log
	done
	echo "===== SHA-256"
	sha256sum $L/*.log
} > $O 2>&1
cat $O
