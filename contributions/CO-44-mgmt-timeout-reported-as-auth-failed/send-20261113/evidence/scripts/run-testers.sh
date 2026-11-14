#!/bin/bash
# usage: run-testers.sh <base|patched>   (QEMU guests through BlueZ tools/test-runner)
set -u
W=/root/exp/agent-work/co44-send-20261113
B=$W/bluez
T=$1
K=$W/kernels/bzImage-$T
L=$W/logs/testers
mkdir -p $L
$B/tools/test-runner -k $K -- $B/tools/mgmt-tester -s "Set Device Class - Timeout 1" > $L/mgmt-newcase-$T.log 2>&1
$B/tools/test-runner -k $K -- $B/tools/mgmt-tester > $L/mgmt-full-$T.log 2>&1
$B/tools/test-runner -k $K -- $B/tools/l2cap-tester > $L/l2cap-full-$T.log 2>&1
$B/tools/test-runner -k $K -- $B/tools/smp-tester > $L/smp-full-$T.log 2>&1
echo done > $L/RUN-DONE-$T
