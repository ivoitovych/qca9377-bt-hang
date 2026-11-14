#!/bin/bash
# chain-bt24.sh: after the E / E+F batches, the BT-24 runs on the A,B2,D-v2 tree (baseline and fixed)
w=/root/exp/agent-work/lane1-btusb-20261114/task2
# (As run, this line waited until the previous batch's output reported "chain done"; that output
# was a session-temporary file, so the wait is not kept here. Run it after the E / E+F batch.)
"$w/harness/run-batch.sh" "$w/harness/spec-bt24-b2tree.txt" "$w/logs/summary-bt24-b2tree.txt"
echo chain done
