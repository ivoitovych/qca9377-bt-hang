#!/bin/bash
# Step 3: the adjacent-state variants (12 per run), 10 runs, on one tree.
S=/root/exp/agent-work/co23-co37-review-20261101/scripts/asan-tree.sh
$S test "$1" adj 10 test/functional/test_local_adjacent.py
