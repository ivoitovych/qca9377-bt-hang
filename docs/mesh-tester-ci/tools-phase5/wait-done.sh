#!/bin/bash
# wait-done.sh <seconds> - wait until gates-final.log has "### done" or the
# given number of seconds passed, then print the log's last lines.
L=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/logs/phase5/gates-final.log
end=$((SECONDS + ${1:-90}))
while [ "$SECONDS" -lt "$end" ]; do
	grep -q '^### done' "$L" && break
	sleep 5
done
grep -E '^(== .* (start|end)|###|Total:)' "$L" | tail -n 6
