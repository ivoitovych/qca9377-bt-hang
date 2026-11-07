#!/bin/bash
# Step 4: CO-37's two tests with the RFC alone and with RFC + CO-37,
# 10 runs each.
S=/root/exp/agent-work/co23-co37-review-20261101/scripts/asan-tree.sh
$S test "$1" co37 10 test/functional/test_a2dp.py -k acquired_transport
