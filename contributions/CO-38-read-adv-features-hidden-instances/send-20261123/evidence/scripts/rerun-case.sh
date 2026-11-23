#!/bin/bash
# rerun-case.sh <line> <n> <case name> : run one mgmt-tester case n times on <line>'s base and patched images
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
B=$W/bluez
Q=$R/tmp/mesh-tester-ci/qemu-smp.sh
L=${1:?line}; N=${2:?n}; C=${3:?case}
tag=$(echo "$C" | tr -c 'A-Za-z0-9' '_' | cut -c1-40)
mkdir -p "$W/reruns"
for v in base patched; do
	for k in $(seq 1 "$N"); do
		log=$W/reruns/$L-$v-$tag-$k.log
		[[ -e $log ]] && continue
		(cd "$B" && nice -n 19 timeout 300 "$B/tools/test-runner" -q "$Q" -k "$W/img/bzImage-$L-$v" -- "$B/tools/mgmt-tester" -s "\"$C\"") > "$log" 2>&1
		echo "$L $v $k: $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Total:')"
	done
done
