#!/bin/bash
# chain-t3.sh: waits for the t2-a batch to finish, then runs the step 3 specs (one guest at a time)
w=/root/exp/agent-work/lane1-btusb-20261114/task1
until grep -q "^batch:" "$w/logs/summary-t2-a.txt"; do sleep 20; done
"$w/harness/run-batch.sh" "$w/harness/spec-t3-delay.txt" "$w/logs/summary-t3-delay.txt"
"$w/harness/run-batch.sh" "$w/harness/spec-t3-matrix.txt" "$w/logs/summary-t3-matrix.txt"
echo chain done
