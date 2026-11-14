#!/bin/bash
# chain-backlog.sh: once the tip kernel image exists, the 10 boots per kernel (tip, tip + CO-04)
w=/root/exp/agent-work/lane1-btusb-20261114
until [ -e "$w/img/bzImage-m-tip.commit" ]; do sleep 20; done
"$w/task4/harness/run-batch.sh" "$w/task4/harness/spec-backlog.txt" "$w/task4/logs/summary-backlog.txt"
echo chain done
