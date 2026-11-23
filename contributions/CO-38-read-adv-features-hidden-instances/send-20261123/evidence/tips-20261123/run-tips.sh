#!/bin/bash
# run-tips.sh [tree...] : on each tree's base, co38 and co44 images (build-tips.sh), each new case 3 times on base and on
# its own patch's image, then the 10 BlueZ testers the upstream kernel CI runs, in full, on all three, one guest at a time. Logs: $W2/runs/<tree>-<v>-<what>.log
# (compare-tips.py pairs base with co38 and with co44). A guest is stopped at 1800 s; a run that hits it is named in progress.log.
set -u
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
W2=$W/tips2
B=$W/bluez
Q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
say() { echo "$(date -u '+%F %T') UTC $*" | tee -a "$W/progress.log"; }
mkdir -p "$W2/runs"
TREES=("$@"); [[ ${#TREES[@]} -gt 0 ]] || TREES=(next main 7.3 6.18 6.12 6.6 6.1)
run() { # <log> <cmd...>
	# Hang watchdog (2026-11-23): a kernel hang in the guest (for example the known L2CAP deferred-accept hang,
	# CO-35, on lines without its fix) leaves the guest idle until the timeout. When the hung-task detector has
	# reported a task blocked for 60 s, the guest is stopped and the log ends with a HUNG line naming the case.
	local log=$1; shift
	[[ -e $log ]] && return 0
	(cd "$B" && exec nice -n 19 timeout 1800 "$B/tools/test-runner" -q "$Q" -k "$IMG" -- "$@") > "$log" 2>&1 &
	local pid=$! hung=""
	while kill -0 "$pid" 2>/dev/null; do
		if grep -a -q -E 'blocked for more than (6[0-9]|[7-9][0-9]|[0-9]{3,}) seconds' "$log"; then
			hung=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E ' - run$' | tail -n 1 | sed -e 's/ - run$//')
			kill -TERM "$pid" 2>/dev/null
			break
		fi
		sleep 10
	done
	wait "$pid"
	local rc=$?
	if [[ -n $hung ]]; then
		echo "HUNG in: $hung (guest stopped by the run-tips watchdog after a 60 s hung-task report)" >> "$log"
		say "tips $(basename "$log" .log) HUNG in \"$hung\""
		return 0
	fi
	say "tips $(basename "$log" .log) rc=$rc $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Total:' | tail -n 1)"
}
for t in "${TREES[@]}"; do
	for v in base co38 co44; do
		IMG=$W2/img/bzImage-$t-$v
		[[ -e $IMG ]] || { say "tips: no image $IMG"; continue; }
		for k in 1 2 3; do
			[[ $v == co44 ]] || run "$W2/runs/$t-$v-co38-case$k.log" "$B/tools/mgmt-tester" -s '"Read Advertising Features - Success 3 (Instance 2 only)"'
			[[ $v == co38 ]] || run "$W2/runs/$t-$v-co44-case$k.log" "$B/tools/mgmt-tester" -s '"Set Device Class - Timeout 1"'
		done
		for s in bnep iso l2cap mgmt rfcomm sco ioctl mesh smp userchan; do   # the testers the upstream kernel CI runs
			run "$W2/runs/$t-$v-$s-full.log" "$B/tools/$s-tester"
		done
	done
done
say "tips runs done"
