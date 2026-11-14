#!/bin/bash
# compare-all.sh - CO-38: totals per log, then plain-n vs fix-n verdict comparison, and the scan of every guest log
W=/root/exp/agent-work/lane3-mgmt-20261114
L=$W/CO-38/logs
C=/root/exp/qca9377-bt-hang/scripts/compare-tester-verdicts.py
for t in mgmt mesh; do
	for img in plain fix; do
		for n in 1 2 3; do
			echo "== $t-$img-$n: $(sed -e 's/\x1b\[[0-9;]*m//g' "$L/$t-$img-$n.log" | grep -a -E '^Total:' | tail -n 1)"
		done
	done
	for n in 1 2 3; do
		echo "== compare $t plain-$n vs fix-$n"
		python3 -I "$C" "$L/$t-plain-$n.log" "$L/$t-fix-$n.log"
	done
done
echo "== compare mgmt plain-1 vs plain-2 vs plain-3 (run-to-run, same kernel)"
python3 -I "$C" "$L/mgmt-plain-1.log" "$L/mgmt-plain-2.log"
python3 -I "$C" "$L/mgmt-plain-1.log" "$L/mgmt-plain-3.log"
echo "== compare mgmt fix-1 vs fix-2, fix-3"
python3 -I "$C" "$L/mgmt-fix-1.log" "$L/mgmt-fix-2.log"
python3 -I "$C" "$L/mgmt-fix-1.log" "$L/mgmt-fix-3.log"
echo "== kernel-report-scan, all logs"
python3 -I /root/exp/qca9377-bt-hang/scripts/kernel-report-scan.py "$L"/mgmt-*.log "$L"/mesh-*.log
echo "rc=$?"
