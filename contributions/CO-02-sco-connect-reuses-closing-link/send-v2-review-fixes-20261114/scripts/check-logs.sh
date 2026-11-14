#!/bin/bash
# check-logs.sh : per run log, the totals and the number of lockdep / KASAN / BUG / WARNING lines
W=/root/exp/agent-work/lane7-sco-20261114
for f in "$W"/logs/run-*.log; do
	tot=$(grep -a -E 'Total: ' "$f" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')
	ld=$(grep -a -c -E 'possible circular locking|possible recursive locking|inconsistent lock state|lock held when returning|suspicious RCU|DEADLOCK' "$f")
	ka=$(grep -a -c 'KASAN:' "$f")
	bug=$(grep -a -c -E 'BUG:|WARNING:|Oops|general protection' "$f")
	echo "$(basename "$f") | $tot | lockdep=$ld kasan=$ka bug_or_warning=$bug"
done
