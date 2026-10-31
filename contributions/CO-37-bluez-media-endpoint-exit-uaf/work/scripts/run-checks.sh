#!/bin/bash
# run-checks.sh: after the base rate run, one container at a time:
# fix1 exit-test rate, CheckPatch on the series, make check on base and
# base+fixes, the whole functional suite on base and base+fixes.
set -u
W=/root/exp/agent-work/exit-uaf
T=$W/scripts/asan-tree.sh
$T test fix1 "test_a2dp_exit_with_acquired_transport" 10 exit-rate
$W/scripts/checkpatch.sh $W/patches/master/*.patch
$T check base-t0
$T check fix12
$T suite base-t0 suite
$T suite fix12 suite
