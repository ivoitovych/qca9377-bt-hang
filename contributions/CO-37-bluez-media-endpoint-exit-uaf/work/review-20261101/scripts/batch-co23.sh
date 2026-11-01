#!/bin/bash
# Step 1: the CO-23 test before and after the fix, 5 runs each, then the
# finalizer checks (a deliberate failure while the peer is stopped, with
# the new plugin and with the first version's helper) on co23-after.
S=/root/exp/agent-work/co23-co37-review-20261101/scripts/asan-tree.sh
$S test co23-before co23 5 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
$S test co23-after co23 5 test/functional/test_a2dp.py -k test_a2dp_reconfigure_during_close
$S test co23-after pause 1 test/functional/test_local_pause.py -k "pause_fails or no_stopped"
$S test co23-after orig 1 test/functional/test_local_pause.py -k "original_fails or no_stopped"
