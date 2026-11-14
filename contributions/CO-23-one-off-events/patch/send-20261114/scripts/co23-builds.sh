#!/bin/bash
S=/root/exp/agent-work/lane2-sco-20261114/scripts/asan-tree.sh
$S build base-test 20ffd285b58facfd1f2478d159a5f941b09d5be1 9184e1e4f || exit 1
$S build fix-test 20ffd285b58facfd1f2478d159a5f941b09d5be1 08e3e4330 9184e1e4f || exit 1
echo "co23 builds done"
