#!/bin/bash
# chain-t3.sh: the E-tree runs, then (once the E+F image exists) the E+F runs
w=/root/exp/agent-work/lane1-btusb-20261114
"$w/task2/harness/run-batch.sh" "$w/task2/harness/spec-t3-e.txt" "$w/task2/logs/summary-t3-e.txt"
until [ -e "$w/img/bzImage-ef-kml-dbg.commit" ]; do sleep 20; done
"$w/task2/harness/run-batch.sh" "$w/task2/harness/spec-t3-ef.txt" "$w/task2/logs/summary-t3-ef.txt"
echo chain done
