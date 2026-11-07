#!/bin/bash
# run-pwrcmp.sh <boots> - the 2026-10-05 power-off comparison cases (project
# research mesh-tester ab927447, -s PwrCmp) on bluetooth-next 42b8c2d729268
# (base) and base + patchwork 14864878 as posted (b-14864878), alternating,
# one guest at a time (run-vm.sh), 4 CPUs, KASAN + lockdep images.
set -u
R=/root/exp/agent-work/research-mesh
T=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin/mesh-tester-gates-ab927447
W=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/gates-asan.sh
N="${1:-2}"
echo "== pwrcmp set start $(date '+%F %T') boots $N" | tee -a "$R/progress.log"
for i in $(seq 1 "$N"); do
	for k in base-42b8c2d b-14864878; do
		"$R/scripts/run-vm.sh" "pwrcmp-$k-$i" "$k" "$W" "$T" -s PwrCmp | grep -a -E '== vm|Total:|Failed|Timed out|clean|report' | cut -c1-150
	done
done
echo "== pwrcmp set end $(date '+%F %T')" | tee -a "$R/progress.log"
