#!/bin/bash
# finish-logs.sh: logs/metrics.txt and SHA256SUMS for logs, patches and harness (task 2)
w=/root/exp/agent-work/lane1-btusb-20261114/task2
python3 -I "$w/harness/metrics.py" "$w"/logs/runs/*.log >"$w/logs/metrics.txt"
cd "$w/logs" || exit 1
sha256sum runs/* summary-*.txt metrics.txt >SHA256SUMS
cd "$w/patches" || exit 1
sha256sum series/*.patch on-E/*.patch ./*.txt >SHA256SUMS
cd "$w/harness" || exit 1
sha256sum ./*.py ./*.sh ./*.txt >SHA256SUMS
