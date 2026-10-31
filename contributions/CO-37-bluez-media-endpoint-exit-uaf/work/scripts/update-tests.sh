#!/bin/bash
# update-tests.sh <a2dp test commit> <discovery test commit> <tree>...
# Replace test/functional/test_a2dp.py and test_exit_discovery.py in the
# built trees runs/<tree>/src with the versions of the given commits of
# ../repo (Python only; the builds stay valid), and note it in
# runs/<tree>/commits.txt.
set -eu
W=/root/exp/agent-work/exit-uaf
a2dp=$1 disc=$2
shift 2
for t in "$@"; do
	s=$W/runs/$t/src
	git -C "$s" fetch -q "$W/repo" exit-uaf-fix exit-uaf-test
	git -C "$s" checkout "$a2dp" -- test/functional/test_a2dp.py
	git -C "$s" checkout "$disc" -- test/functional/test_exit_discovery.py
	echo "$(date '+%H:%M:%S') tests replaced: test_a2dp.py from $a2dp, test_exit_discovery.py from $disc" | tee -a "$W/runs/$t/commits.txt"
done
