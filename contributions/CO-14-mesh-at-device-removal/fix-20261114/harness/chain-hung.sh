#!/bin/bash
# chain-hung.sh: after the BlueZ testers, the hung-controller removal runs on the tip and on tip + CO-04
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "^batch:" "$w/task4/logs/summary-testers.txt" 2>/dev/null; do sleep 20; done
"$w/task4/harness/run-batch.sh" "$w/task4/harness/spec-hung.txt" "$w/task4/logs/summary-hung.txt"
echo chain done
