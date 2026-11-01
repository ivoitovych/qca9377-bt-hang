#!/bin/bash
# run-matrix.sh - research-sco: BlueZ testers in QEMU/KVM guests, one guest at a time.
# Usage: run-matrix.sh <runs> <cpus 1|4> <kernel tags, comma-separated> <testers, comma-separated> [tester args...]
#   kernel tag K -> img/bzImage-K ; tester T -> bin/T
# Logs: logs/run-<K>-<T>-c<cpus>-<n>.log (refuses to overwrite).
set -u
W=/root/exp/agent-work/research-sco
B=$W/bluez-b0bf
N=${1:?usage}; CPUS=${2:?usage}; KS=${3:?usage}; TS=${4:?usage}
shift 4
opts=()
if [[ "$CPUS" == 4 ]]; then opts+=(-q /root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh); fi
IFS=, read -r -a kernels <<< "$KS"
IFS=, read -r -a testers <<< "$TS"
echo "start $(date '+%T') runs=$N cpus=$CPUS kernels=$KS testers=$TS args=$*" >> "$W/progress.log"
cd "$B" || exit 2
for n in $(seq 1 "$N"); do
	for k in "${kernels[@]}"; do
		for t in "${testers[@]}"; do
			log=$W/logs/run-$k-$t-c$CPUS-$n.log
			[[ -e "$log" ]] && { echo "exists, skipped: $log"; continue; }
			echo "start $(date '+%T') kernel $k tester $t run $n cpus $CPUS args $*" > "$log"
			timeout 900 tools/test-runner "${opts[@]}" -k "$W/img/bzImage-$k" -- "$W/bin/$t" "$@" >> "$log" 2>&1
			echo "exit=$? end $(date '+%T')" >> "$log"
			echo "$k $t c$CPUS #$n: $(grep -a -E 'Total: ' "$log" | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')"
		done
	done
done
echo "end $(date '+%T') runs=$N cpus=$CPUS kernels=$KS testers=$TS" >> "$W/progress.log"
