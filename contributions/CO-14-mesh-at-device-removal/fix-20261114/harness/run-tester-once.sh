#!/bin/bash
# run-tester-once.sh <kernel tag> <tester> <log label> [tester args...]
# One guest (4 CPUs, 2 GB) running one of the project's prebuilt BlueZ testers (tmp/co05-w4/bin) with the
# given arguments. Log: logs/runs/tester-<label>.log; prints the Total line. 3600 s limit.
set -u
ulimit -c 0
l=/root/exp/agent-work/lane1-btusb-20261114
w=$l/task4
b=/root/exp/qca9377-bt-hang/tmp/co05-w4/bin
q=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
k=${1:?usage}
t=${2:?usage}
label=${3:?usage}
shift 3
log=$w/logs/runs/tester-$label.log
[ -e "$log" ] && { echo "exists: $log"; exit 2; }
QEMU_SMP=4 timeout 3600 "$b/test-runner" -q "$q" -o -m -o 2G -k "$l/img/bzImage-$k" -- "$b/$t-master-4dc15be8" "$@" >"$log" 2>&1 </dev/null
rc=$?
echo "$t $k $label rc=$rc $(sed -e 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E 'Total: ' | tail -n 1)"
exit $rc
