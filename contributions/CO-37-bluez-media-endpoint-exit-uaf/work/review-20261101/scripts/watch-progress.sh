#!/bin/bash
# watch-progress.sh <pattern> <count> <max seconds>
# Print each new progress.log line; exit when <count> lines match
# <pattern> or after <max seconds>.
P=/root/exp/agent-work/co23-co37-review-20261101/progress.log
pat=$1 want=$2 max=$3
seen=$(wc -l < "$P")
start=$(date +%s)
while true; do
	now=$(wc -l < "$P")
	if (( now > seen )); then
		sed -n "$((seen + 1)),${now}p" "$P"
		seen=$now
	fi
	if (( $(grep -c -E "$pat" "$P") >= want )); then
		echo "WATCH DONE: $want lines match '$pat'"
		exit 0
	fi
	if (( $(date +%s) - start > max )); then
		echo "WATCH TIMEOUT after $max s"
		exit 1
	fi
	sleep 5
done
