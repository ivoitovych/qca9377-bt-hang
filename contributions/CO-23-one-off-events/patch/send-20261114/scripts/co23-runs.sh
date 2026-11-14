#!/bin/bash
S=/root/exp/agent-work/lane2-sco-20261114/scripts/asan-tree.sh
$S test base-test co23 10 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
$S test fix-test co23 10 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
$S test base-test a2dp 1 test/functional/test_a2dp.py
$S test fix-test a2dp 1 test/functional/test_a2dp.py
echo "co23 runs done"
