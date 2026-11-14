#!/bin/bash
# build and test everything, one step at a time (one guest at a time, make -j4)
W=/root/exp/agent-work/lane5-status-stable-20261114/co35
say() { echo "$(date -u '+%F %T') UTC ALL: $*" >> "$W/progress.log"; }
one() { # tag line variant full|nofull
	say "step $1 $3"
	"$W/build.sh" "$1" "$2" "$3" 4 || { say "BUILD FAILED $1 $3"; return 1; }
	"$W/run-test.sh" "$W/img/bzImage-$1-$3" "$W/logs/case-$1-$3.log" 180 exact >> "$W/logs/summary-$1-$3.txt" 2>&1
	if [[ $4 == full ]]; then "$W/run-test.sh" "$W/img/bzImage-$1-$3" "$W/logs/full-$1-$3.log" 900 all >> "$W/logs/summary-full-$1-$3.txt" 2>&1; fi
}
one v7.3.4 7.3.y base nofull
one v7.3.4 7.3.y pair nofull
one v7.3.4 7.3.y pair-sci full
one v6.18.63 6.18.y pair full
one v6.18.63 6.18.y base nofull
one v6.12.117 6.12.y pair full
one v6.12.117 6.12.y base nofull
one v6.6.162 6.6.y pair full
one v6.6.162 6.6.y base nofull
say "ALL-DONE"
