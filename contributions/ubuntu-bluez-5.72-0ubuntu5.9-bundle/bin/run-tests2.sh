#!/bin/bash
# after run-tests.sh: the btmon live job (with the btmon binaries of the replay), and R310 again on the bundle image
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
say() { echo "$(date -u '+%F %T') UTC TESTS2: $*" >> "$B/logs/progress.log"; }
rm -rf "$B/btmon-live/out/live-bundle"
say "btmon live"
"$B/btmon-live/scripts/vm.sh" live-bundle > "$B/logs/btmon-live-vm.log" 2>&1
say "R310 again on the bundle image (3 runs)"
"$B/bin/run-inst.sh" bundle572-installed:bundle inst-bundle-r310 3 "r310"
say "TESTS2-DONE"
