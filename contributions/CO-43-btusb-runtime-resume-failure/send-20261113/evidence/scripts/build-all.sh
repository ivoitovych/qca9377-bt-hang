#!/bin/bash
# build-all.sh: the five guest kernels of this task, in order (the first build is the full one)
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
log=$w/build/build-all.log
mkdir -p "$w/build"
for pair in "ea-base ea-base-20261113" "ea-e ea-e-20261113" "ea-base-dbg ea-base-dbg-20261113" \
	"ea-e-dbg ea-e-dbg-20261113" "ea-a ea-a-20261113"; do
	set -- $pair
	echo "== $(date '+%F %T') build $1 from $2" >>"$log"
	"$w/scripts/build-ea.sh" "$1" "$2" >>"$log" 2>&1 || { echo "== build $1 FAILED" >>"$log"; exit 1; }
	echo "== $(date '+%F %T') built $1" >>"$log"
done
echo "== all built" >>"$log"
