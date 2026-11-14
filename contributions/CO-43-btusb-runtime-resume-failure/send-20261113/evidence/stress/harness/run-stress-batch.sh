#!/bin/bash
# run-stress-batch.sh <kernel tag> <label prefix> <first run> <last run> [extra emulator args...]
# Runs the stress scenario (100 cycles; seed 1000 + run number) once per run number, one guest each,
# sequentially, through run-guest.sh with a 900 s guest timeout. Every run is judged by its exit
# status. Summary: stress/logs/matrix-<tag>-<prefix>-<first>-<last>.txt: per run the exit status,
# the RESULT line, and every PARKED, KERNEL-REPORT, KERNEL-TIMEOUT and TEARDOWN-TIMEOUT line.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
h=$w/stress/harness
tag=${1:?usage}
prefix=${2:?usage}
a=${3:?usage}
b=${4:?usage}
shift 4
export GUEST_TIMEOUT=900
out=$w/stress/logs/matrix-$tag-$prefix-$a-$b.txt
: >"$out"
failed=0
for n in $(seq "$a" "$b"); do
	label=$prefix-$n
	"$h/run-guest.sh" "$tag" "$label" stress --cycles 100 --seed $((1000 + n)) "$@" >/dev/null
	rc=$?
	[ $rc -eq 0 ] || failed=$((failed + 1))
	echo "$tag $label exit=$rc requeued_events=$(grep -a -c 'event bytes put back' "$w/stress/logs/$tag-$label.log")" >>"$out"
	grep -a -h -E "RESULT stress|PARKED|KERNEL-REPORT|KERNEL-TIMEOUT|TEARDOWN-TIMEOUT|WATCHDOG|scenario raised|KMEMLEAK-OTHER" "$w/stress/logs/$tag-$label.log" |
		sed "s/^/$tag $label: /" >>"$out"
done
echo "batch $tag $prefix $a-$b done: $out; non-zero runs: $failed" | tee -a "$out"
[ "$failed" -eq 0 ]
