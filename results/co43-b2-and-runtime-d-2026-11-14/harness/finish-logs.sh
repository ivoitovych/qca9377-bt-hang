#!/bin/bash
# finish-logs.sh: writes logs/metrics.txt (metrics.py over every run log) and logs/SHA256SUMS
w=/root/exp/agent-work/lane1-btusb-20261114/task1
python3 -I "$w/harness/metrics.py" "$w"/logs/runs/*.log >"$w/logs/metrics.txt"
cd "$w/logs" || exit 1
sha256sum runs/* summary-*.txt metrics.txt >SHA256SUMS
cd "$w/patches" || exit 1
sha256sum ./*.patch >SHA256SUMS
cd "$w/harness" || exit 1
sha256sum ./* >SHA256SUMS
