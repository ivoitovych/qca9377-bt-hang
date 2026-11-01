#!/bin/bash
# Step 2: the three new tests together, and the whole A2DP functional
# file, on the stacked base (tests only) and the stacked series.
S=/root/exp/agent-work/co23-co37-review-20261101/scripts/asan-tree.sh
for t in stk-base stk-fix12; do
	$S test $t pair 3 test/functional/test_a2dp.py -k "reconfigure_during_close or acquired_transport"
done
for t in stk-base stk-fix12; do
	$S test $t a2dpfile 2 test/functional/test_a2dp.py
done
