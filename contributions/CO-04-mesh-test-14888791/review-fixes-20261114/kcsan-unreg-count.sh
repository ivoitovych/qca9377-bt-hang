#!/bin/bash
# kcsan-unreg-count.sh - per image and set: boots, boots with any KCSAN report, with a report naming mesh/adv code
# (kcsan-summary.py); output CO-04/kcsan-unreg-count.txt
W=/root/exp/agent-work/lane3-mgmt-20261114
T=$W/task3-20261114/CO-04
S=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/kcsan-summary.py
exec > "$T/kcsan-unreg-count.txt" 2>&1
for set in UnregSweep unregister; do
	for k in kbase kco04; do
		b=0; a=0; m=0
		for f in "$T"/kcsan-logs/$set-$k-*.log; do
			b=$((b + 1))
			python3 -I "$S" "$f" > "$f.kcsan.txt"
			n=$(grep -c -E "^   line [0-9]+ " "$f.kcsan.txt")
			c=$(grep -E "^   line [0-9]+ " "$f.kcsan.txt" | grep -c -E "mesh|adv|mgmt_pending")
			[ "$n" -gt 0 ] && a=$((a + 1))
			[ "$c" -gt 0 ] && m=$((m + 1))
		done
		echo "$set $k: boots $b, any KCSAN report $a, naming mesh/adv/mgmt_pending code $m"
	done
done
