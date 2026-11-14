#!/bin/bash
# summarize.sh - totals per log and the verdict comparisons of the CO-12 clamp runs; output CO-12/summary.txt
W=/root/exp/agent-work/lane3-mgmt-20261114/CO-12
L=$W/logs
C=/root/exp/qca9377-bt-hang/scripts/compare-tester-verdicts.py
exec > "$W/summary.txt" 2>&1
for f in "$L"/*.log; do
	echo "$(basename "$f" .log): $(sed -e 's/\x1b\[[0-9;]*m//g' "$f" | grep -a -E '^Total:' | tail -n 1)"
done
for n in 1 2 3; do
	echo "== AdvDur plain vs clamp, run $n"; python3 -I "$C" "$L/AdvDur-plain-$n.log" "$L/AdvDur-clamp-$n.log"
	echo "== Add plain vs clamp, run $n"; python3 -I "$C" "$L/Add-plain-$n.log" "$L/Add-clamp-$n.log"
	echo "== Add fix vs clampfix, run $n"; python3 -I "$C" "$L/Add-fix-$n.log" "$L/Add-clampfix-$n.log"
	echo "== Advertising plain vs clamp, run $n"; python3 -I "$C" "$L/Adv-plain-$n.log" "$L/Adv-clamp-$n.log"
done
echo "== kernel-report-scan"
python3 -I /root/exp/qca9377-bt-hang/scripts/kernel-report-scan.py "$L"/*.log
echo "rc=$?"
