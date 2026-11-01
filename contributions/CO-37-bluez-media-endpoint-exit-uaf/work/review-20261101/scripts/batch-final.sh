#!/bin/bash
# Final test versions (tests from srcs/, binaries from the built trees):
# step 1, the CO-23 test before and after the fix, 5 runs each;
# step 2, the three new tests together (3 runs) and the whole A2DP file
# (2 runs), stacked base vs stacked series.
W=/root/exp/agent-work/co23-co37-review-20261101
S=$W/scripts/asan-tree.sh
$S testsrc co23-before $W/srcs/co23 final 5 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
$S testsrc co23-after $W/srcs/co23 final 5 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
for t in stk-base stk-fix12; do
	$S testsrc $t $W/srcs/stack fpair 3 test/functional/test_a2dp.py -k "reconfigure_during_close or acquired_transport"
done
for t in stk-base stk-fix12; do
	$S testsrc $t $W/srcs/stack fa2dp 2 test/functional/test_a2dp.py
done
