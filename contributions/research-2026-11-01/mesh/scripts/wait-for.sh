#!/bin/bash
# wait-for.sh <fixed string> <max seconds> - wait until progress.log has the
# string; print it (or TIMEOUT) and exit.
set -u
R=/root/exp/agent-work/research-mesh
S="${1:?string}"
M="${2:-900}"
for _ in $(seq 1 "$M"); do
	if grep -q -F "$S" "$R/progress.log"; then
		grep -F "$S" "$R/progress.log" | tail -n 1
		exit 0
	fi
	sleep 1
done
echo "TIMEOUT waiting for $S"
exit 1
