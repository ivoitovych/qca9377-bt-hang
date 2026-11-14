#!/bin/bash
# every VM test, one guest at a time: base 5.72-0ubuntu5.8 vs the bundle
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
say() { echo "$(date -u '+%F %T') UTC TESTS: $*" >> "$B/logs/progress.log"; }
cp "$B/tree-base/bluez-5.72/monitor/btmon" "$B/btmon-live/bin/btmon-base58"
cp "$B/tree/bluez-5.72/monitor/btmon" "$B/btmon-live/bin/btmon-bundle"
mkdir -p "$B/co40"
say "1 installed packages: U12 trigger and control, R300 identity, R310 with Noble's PipeWire (3 runs each)"
"$B/bin/run-inst.sh" bundle572-installed:stock inst-stock 3
"$B/bin/run-inst.sh" bundle572-installed:bundle inst-bundle 3
say "2 CO-40: refused vs unknown"
"$B/bin/run-co40.sh" base base-hold 10 hold_after_key
"$B/bin/run-co40.sh" bundle bundle-hold 10 hold_after_key
"$B/bin/run-co40.sh" base base-none 5 none
"$B/bin/run-co40.sh" bundle bundle-none 5 none
say "3 U23 and U24 exit runs (CO-37's harness)"
"$B/bin/exit-test.sh" e572base test_a2dp_exit_with_acquired_transport 10 exit-rate
"$B/bin/exit-test.sh" e572bundle test_a2dp_exit_with_acquired_transport 10 exit-rate
"$B/bin/exit-test.sh" e572base "test_exit_discovering and bus" 10 disc-rate
"$B/bin/exit-test.sh" e572bundle "test_exit_discovering and bus" 10 disc-rate
say "4 U12 trigger rates T201-T207 x10 on the ASan builds"
CO03_REPS=10 "$B/bin/run-l2.sh" base base-l2rates -k "t201 or t202 or t203 or t204 or t205 or t206 or t207"
CO03_REPS=10 "$B/bin/run-l2.sh" bundle bundle-l2rates -k "t201 or t202 or t203 or t204 or t205 or t206 or t207"
say "5 btmon live (pty, monitor socket) base vs bundle"
"$B/btmon-live/scripts/vm.sh" live-bundle > "$B/logs/btmon-live-vm.log" 2>&1
say "6 U12 L2, all 31 tests once"
"$B/bin/run-l2.sh" base base-l2
"$B/bin/run-l2.sh" bundle bundle-l2
say "TESTS-DONE"
