#!/bin/bash
# run-full-again.sh <line> <variant> <n> : n more full mgmt-tester runs on one image, logs in $W/reruns
set -u
R=/root/exp/qca9377-bt-hang
W=${KQ_WORK:?set KQ_WORK to the work area (worktree, images, logs)}
B=$W/bluez
Q=$R/tmp/mesh-tester-ci/qemu-smp.sh
L=${1:?line}; V=${2:?variant}; N=${3:?n}
mkdir -p "$W/reruns"
for k in $(seq 1 "$N"); do
	log=$W/reruns/$L-$V-mgmt-full-again$k.log
	[[ -e $log ]] && continue
	(cd "$B" && nice -n 19 timeout 3600 "$B/tools/test-runner" -q "$Q" -k "$W/img/bzImage-$L-$V" -- "$B/tools/mgmt-tester") > "$log" 2>&1
	echo "$L $V full $k: $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Total:')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E '^Pairing Acceptor - SMP over BR/EDR 2 '
done
