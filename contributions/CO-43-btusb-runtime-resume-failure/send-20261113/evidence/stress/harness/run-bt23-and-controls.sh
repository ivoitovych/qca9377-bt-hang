#!/bin/bash
# run-bt23-and-controls.sh: on the debug-only kernels (ea-base-dbg = base + the bt23_delay_ms
# parameter; ea-e-dbg = base + E + the same parameter):
#  1. the bt23 scenario (delay 400 ms after the suspend decision, a resume forced inside it), three
#     runs each, interleaved;
#  2. the stress scenario as a positive control, with bt23_delay_ms = 30 for the whole run, two runs
#     each: it must find parked packets on ea-base-dbg and none on ea-e-dbg.
# Every run is judged by its exit status. Summary: stress/logs/matrix-bt23-controls.txt.
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
h=$w/stress/harness
out=$w/stress/logs/matrix-bt23-controls.txt
: >"$out"
for n in 1 2 3; do
	for tag in ea-base-dbg ea-e-dbg; do
		"$h/run-guest.sh" "$tag" "bt23-$n" bt23 --delay 400 >/dev/null
		echo "$tag bt23-$n exit=$?" >>"$out"
		grep -a -h -E "RESULT bt23|tx timeout|BT17-EXIT" "$w/stress/logs/$tag-bt23-$n.log" | grep -a -v KMSG | sed "s/^/$tag bt23-$n: /" >>"$out"
	done
done
export GUEST_TIMEOUT=900
for n in 1 2; do
	for tag in ea-base-dbg ea-e-dbg; do
		"$h/run-guest.sh" "$tag" "ctl-$n" stress --cycles 100 --seed $((2000 + n)) --bt23-delay 30 >/dev/null
		echo "$tag ctl-$n exit=$? requeued_events=$(grep -a -c 'event bytes put back' "$w/stress/logs/$tag-ctl-$n.log") parked_lines=$(grep -a -c '^.*PARKED cycle' "$w/stress/logs/$tag-ctl-$n.log")" >>"$out"
		grep -a -h -E "RESULT stress|KERNEL-REPORT|WATCHDOG|scenario raised" "$w/stress/logs/$tag-ctl-$n.log" | sed "s/^/$tag ctl-$n: /" >>"$out"
	done
done
echo "done" >>"$out"
