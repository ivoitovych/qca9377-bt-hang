#!/bin/sh
# Returns when this work area's progress.log has an end line for every
# given run id, or after <max seconds>.
# Usage: wait-runs-end.sh <max seconds> <run id>...
max=$1
shift
P=/root/exp/agent-work/co36-v2v3-20261101/progress.log
i=0
while [ "$i" -lt "$max" ]; do
	all=1
	for r in "$@"; do
		grep -q " $r (v[0-9]) end rc=" "$P" || all=0
	done
	[ "$all" = 1 ] && break
	sleep 10
	i=$((i + 10))
done
for r in "$@"; do
	grep " $r (v[0-9]) end rc=" "$P" || echo "$r not ended after $max s"
done
