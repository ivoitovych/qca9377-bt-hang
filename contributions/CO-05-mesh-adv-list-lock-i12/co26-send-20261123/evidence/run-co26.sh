#!/bin/bash
# run-co26.sh : CO-26 fault injection on the tip. For co26-base and co26-patched, 3 guests each: the first mesh
# add fails with -ENOMEM (bluetooth.scratch_fail_mesh_add=1), kprobe trace of the start path (tmp/co05-w4/co05-guest.sh),
# mesh-tester -s Send. Then the full mesh-tester and mgmt-tester once per image, knob off, as a no-change check.
# Logs: $W/runs-co26/. Skips existing logs.
set -u
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
B=$W/bluez
Q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
G=/root/exp/qca9377-bt-hang/tmp/co05-w4/co05-guest.sh
D=$W/runs-co26
mkdir -p "$D"
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
run() { # <log> <limit> <cmd...>
	local log=$1 lim=$2; shift 2
	[[ -e $log ]] && return 0
	(cd "$B" && nice -n 19 timeout "$lim" "$B/tools/test-runner" -q "$Q" -k "$IMG" -- "$@") > "$log" 2>&1
	say "co26 $(basename "$log") rc=$? $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Total:' | tail -n 1)"
}
for v in base patched; do
	IMG=$W/img/bzImage-co26-$v
	for k in 1 2 3; do
		run "$D/$v-inject-$k.log" 300 "$G" 1 @send
	done
	run "$D/$v-mesh-full.log" 1800 "$B/tools/mesh-tester"
	run "$D/$v-mgmt-full.log" 3600 "$B/tools/mgmt-tester"
done
say "co26 runs done"
