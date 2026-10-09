#!/bin/bash
# wait-gates-final.sh - print each "== ... end" / "###" line of gates-final.log
# as it appears; exit when "### done" is there.
L=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/logs/phase5/gates-final.log
seen=0
while true; do
	n=$(grep -c -E '^(== .* end|###|Total:)' "$L")
	if [ "$n" -gt "$seen" ]; then
		grep -E '^(== .* end|###|Total:)' "$L" | tail -n +"$((seen + 1))"
		seen=$n
	fi
	grep -q '^### done' "$L" && exit 0
	sleep 5
done
