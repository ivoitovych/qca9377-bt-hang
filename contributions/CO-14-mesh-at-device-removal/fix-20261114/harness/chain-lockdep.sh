#!/bin/bash
# chain-lockdep.sh: after the fix boots and the controls, the lockdep hunt on the tip and on tip + CO-04
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "^batch:" "$w/task4/logs/summary-controls.txt" 2>/dev/null; do sleep 20; done
"$w/task4/harness/run-batch.sh" "$w/task4/harness/spec-lockdep.txt" "$w/task4/logs/summary-lockdep.txt"
echo chain done
