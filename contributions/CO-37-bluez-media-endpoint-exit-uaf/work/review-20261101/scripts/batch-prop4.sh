#!/bin/bash
# The a2dp-layer proposal (local experiment): the runtime give-up
# variants, the exit/adapter variants, and the A2DP functional file.
W=/root/exp/agent-work/co23-co37-review-20261101
S=$W/scripts/asan-tree.sh
$S testsrc prop4 $W/srcs/stack adj2 5 test/functional/test_local_adjacent2.py
$S testsrc prop4 $W/srcs/stack adj 3 test/functional/test_local_adjacent.py
$S testsrc prop4 $W/srcs/stack fa2dp 2 test/functional/test_a2dp.py
