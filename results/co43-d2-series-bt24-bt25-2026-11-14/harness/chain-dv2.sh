#!/bin/bash
# chain-dv2.sh: after the D-v2 matrix batch, the delayed-reset runs on ab2dv2-dbg
w=/root/exp/agent-work/lane1-btusb-20261114/task2
until grep -q "^batch:" "$w/logs/summary-dv2-matrix.txt"; do sleep 20; done
"$w/harness/run-batch.sh" "$w/harness/spec-dv2-delay.txt" "$w/logs/summary-dv2-delay.txt"
echo chain done
