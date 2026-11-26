#!/bin/bash
# compare-gaps.sh : the results of run-gaps.sh, base against co38, per log pair.
#  - the new case on next2: passes out of 3 on each side;
#  - every other pair (<tree>-base-<what>.log with <tree>-co38-<what>.log): scripts/compare-tester-verdicts.py, and
#    the HUNG line of either side if there is one;
#  - every log: scripts/kernel-report-scan.py, then the report lines that differ between the two sides.
# Writes $W3/compare-gaps.txt and $W3/report-scan.txt and prints the first.
set -u
R=/root/exp/qca9377-bt-hang
W3=<work area>/tips3
RUNS=$W3/runs
OUT=$W3/compare-gaps.txt
{
	echo "== next2: the new case"
	for v in base co38; do
		n=0
		for k in 1 2 3; do
			f=$RUNS/next2-$v-co38-case$k.log
			[[ -e $f ]] && sed -e 's/\x1b\[[0-9;]*m//g' "$f" | grep -a -q -E '^Read Advertising Features - Success 3 \(Instance 2 only\) +Passed' && n=$((n + 1))
		done
		echo "  $v: $n/3 passed"
	done
	for a in "$RUNS"/*-base-*.log; do
		w=$(basename "$a" .log)
		case $w in *-co38-case*) continue ;; esac
		b=$RUNS/${w/-base-/-co38-}.log
		echo "== $w vs co38"
		[[ -e $b ]] || { echo "  co38 log missing"; continue; }
		for f in "$a" "$b"; do grep -a -h '^HUNG in:' "$f" | sed -e "s|^|  $(basename "$f" .log): |"; done
		python3 -I "$R/scripts/compare-tester-verdicts.py" "$a" "$b" 2>&1 | sed -e 's/^/  /'
	done
} > "$OUT"
python3 -I "$R/scripts/kernel-report-scan.py" "$RUNS"/*.log > "$W3/report-scan.txt" 2>&1
echo "kernel-report-scan exit $? ($W3/report-scan.txt)" >> "$OUT"
cat "$OUT"
