#!/bin/bash
# tally-e123.sh : per kernel image of the early-park series, the guest runs, the hung ones (no Total line) and those with a failed case
W=/root/exp/agent-work/lane7-sco-20261114
for k in ebase e12 e123 e123d parkbase parkB parkC a12 a123 base; do
	n=0; hung=0; failed=0
	for f in "$W"/logs/run-*-"$k"-[0-9]*.log; do
		[[ -e "$f" ]] || continue
		n=$((n + 1))
		if ! grep -a -q "Total: " "$f"; then hung=$((hung + 1)); continue; fi
		if grep -a -q -E "Failed: [1-9]|Timed out" "$f"; then failed=$((failed + 1)); fi
	done
	echo "$k: $n guest runs, $hung without a result (hung or killed), $failed with a failed or timed-out case"
done
