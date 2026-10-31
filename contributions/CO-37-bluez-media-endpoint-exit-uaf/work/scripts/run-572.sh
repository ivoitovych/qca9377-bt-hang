#!/bin/bash
# run-572.sh: ten runs each, one pytest session per test (5.72 cannot pair
# twice in reused guests), on 5.72 and on 5.72 with the backports.
set -u
T=/root/exp/agent-work/exit-uaf/scripts/asan-tree.sh
for tree in v572 v572fix; do
	$T test "$tree" "test_a2dp_exit_with_acquired_transport" 10 exit-rate
	$T test "$tree" "test_exit_discovering and bus" 10 disc-rate
done
