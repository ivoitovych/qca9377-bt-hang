#!/bin/bash
# run-matrix.sh <kernel tag> <first run number> <last run number>
# For each run number: the BT-17 fault (dead device), the command-started resume of a
# device that recovers, the close-started resume of a device that recovers; one guest each,
# sequentially, through run-guest.sh. Then one long healthy run (50 cycles).
# Summary: logs/matrix-<tag>-<first>-<last>.txt (the RESULT lines).
set -u
w=/root/exp/agent-work/bt17-emu-20261113
tag=${1:?usage}
a=${2:?usage}
b=${3:?usage}
out=$w/logs/matrix-$tag-$a-$b.txt
: >"$out"
failed=0
for n in $(seq "$a" "$b"); do
	for sc in "dead bt17 --fail-at 1" "recover bt17 --fail-at 1 --recover" "close close-recover --fail-at 1 --recover"; do
		set -- $sc
		label=$1
		shift
		"$w/harness/run-guest.sh" "$tag" "m-$label-$n" "$@" >/dev/null || failed=$((failed + 1))
		grep -a -h -E "RESULT|Failed usb_autopm|not resumed|Failed to resume|Resetting usb|BUG:|WARNING:|KASAN|possible circular" "$w/logs/$tag-m-$label-$n.log" |
			sed "s/^/$tag $label $n: /" >>"$out"
	done
done
"$w/harness/run-guest.sh" "$tag" "m-cycles50-$a" cycles --cycles 50 >/dev/null || failed=$((failed + 1))
grep -a -h -E "RESULT|latency|BUG:|WARNING:|KASAN" "$w/logs/$tag-m-cycles50-$a.log" | sed "s/^/$tag cycles50: /" >>"$out"
echo "matrix $tag $a-$b done: $out; non-zero runs: $failed"
[ "$failed" -eq 0 ]
