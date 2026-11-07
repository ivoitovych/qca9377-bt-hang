#!/bin/bash
# The proposed third fix (local experiment): both adjacent-state files,
# then the series' own A2DP tests, on the prop3 tree.
W=/root/exp/agent-work/co23-co37-review-20261101
S=$W/scripts/asan-tree.sh
$S testsrc prop3 $W/srcs/stack adj2 10 test/functional/test_local_adjacent2.py
$S testsrc prop3 $W/srcs/stack adj 5 test/functional/test_local_adjacent.py
$S testsrc prop3 $W/srcs/stack fa2dp 2 test/functional/test_a2dp.py
