#!/bin/bash
# run-matrix.sh - CO-38 matrix: images plain and fix, runs 1..3 (mgmt-plain-1 exists), mgmt-tester -p Add
# (128 cases) and mesh-tester -p Mesh (10 cases). Logs CO-38/logs/{mgmt,mesh}-<image>-<n>.log
set -u
W=/root/exp/agent-work/lane3-mgmt-20261114
L=$W/CO-38/logs
I=$W/CO-38/img
B=$W/CO-38/bin
for n in 1 2 3; do
	for img in plain fix; do
		"$W/run-vm.sh" "$L" "mgmt-$img-$n" "$I/bzImage-$img" "$B/mgmt-tester-series" -p Add
		"$W/run-vm.sh" "$L" "mesh-$img-$n" "$I/bzImage-$img" "$B/mesh-tester-series" -p Mesh
	done
done
echo "$(date +%H:%M:%S) CO-38 matrix done" >> "$W/progress.log"
