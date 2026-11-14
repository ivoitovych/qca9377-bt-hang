#!/bin/bash
# chain-fix.sh: after the tip / CO-04 boots and the fix kernel build, the fix boots, then the controls
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "^batch:" "$w/task4/logs/summary-backlog.txt" 2>/dev/null; do sleep 20; done
until [ -e "$w/img/bzImage-m-fix.commit" ]; do sleep 20; done
"$w/task4/harness/run-batch.sh" "$w/task4/harness/spec-fix.txt" "$w/task4/logs/summary-fix.txt"
"$w/task4/harness/run-batch.sh" "$w/task4/harness/spec-controls.txt" "$w/task4/logs/summary-controls.txt"
echo chain done
