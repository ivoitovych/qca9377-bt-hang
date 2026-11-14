#!/bin/bash
# run-matrix.sh <label> <runs> <kernel tags comma-separated> <tester-tag> <tester name> [tester args...]
#   kernel tag K -> img/bzImage-K (lane7) or, if absent, lane2's img/bzImage-K; tester bin/<tester>-<tester-tag>
#   test-runner bin/test-runner-<tester-tag>; btmon bin/btmon. One 4-CPU guest at a time, 3 GB, low priority.
# Logs: logs/run-<label>-<K>-<n>.log (never overwritten). Stops before a guest when /root has under 25 GB free.
if [[ -z "${L7_LOWPRIO:-}" ]]; then
	export L7_LOWPRIO=1
	exec nice -n 10 ionice -c 2 -n 7 "$0" "$@"
fi
set -u
ulimit -c 0
W=/root/exp/agent-work/lane7-sco-20261114
L2=/root/exp/agent-work/lane2-sco-20261114
QEMU=/root/exp/agent-work/lane2-sco-20261114/scripts/qemu-3g.sh
LABEL=${1:?usage}; N=${2:?usage}; KS=${3:?usage}; TT=${4:?usage}; T=${5:?usage}
shift 5
TR=$W/bin/test-runner-$TT
BIN=$W/bin/$T-$TT
BTMON=$W/bin/btmon
IFS=, read -r -a kernels <<< "$KS"
cd "$W/bin" || exit 2
for n in $(seq 1 "$N"); do
	for k in "${kernels[@]}"; do
		avail_kb=$(df -Pk /root | awk 'NR==2 {print $4}')
		if (( avail_kb < 25 * 1024 * 1024 )); then echo "STOP: under 25 GB free"; exit 3; fi
		img=$W/img/bzImage-$k
		[[ -f "$img" ]] || img=$L2/img/bzImage-$k
		[[ -f "$img" ]] || { echo "no image for $k"; exit 2; }
		log=$W/logs/run-$LABEL-$k-$n.log
		[[ -e "$log" ]] && { echo "exists, skipped: $log"; continue; }
		echo "start $(date '+%F %T') kernel $k image $img tester $T-$TT run $n cpus ${QEMU_SMP:-4} args $*" > "$log"
		sha256sum "$img" "$BIN" "$TR" "$BTMON" >> "$log"
		timeout 700 "$TR" -m -q "$QEMU" -k "$img" -- "$BIN" "$@" >> "$log" 2>&1
		echo "exit=$? end $(date '+%F %T')" >> "$log"
		echo "$LABEL $k #$n: $(grep -a -E 'Total: ' "$log" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')"
	done
done
