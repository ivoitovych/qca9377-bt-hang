#!/bin/bash
# Step 3 (runtime give-up variants, 8 per run), 10 runs, on one tree;
# tests from srcs/stack, binaries from the built tree.
W=/root/exp/agent-work/co23-co37-review-20261101
$W/scripts/asan-tree.sh testsrc "$1" $W/srcs/stack adj2 10 test/functional/test_local_adjacent2.py
