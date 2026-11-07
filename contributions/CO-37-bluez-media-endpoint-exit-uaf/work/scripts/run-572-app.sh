#!/bin/bash
# run-572-app.sh: the app-exit test ten times on 5.72 and on 5.72 with the
# backports (the backport's first patch changes what removing an
# application's endpoint does).
set -u
T=/root/exp/agent-work/exit-uaf/scripts/asan-tree.sh
for tree in v572 v572fix; do
	$T test "$tree" "test_a2dp_app_exit_with_acquired_transport" 10 app-rate
done
