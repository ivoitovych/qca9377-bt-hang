#!/bin/bash
# report-scan.sh: the project's scripts/kernel-report-scan.py (from this work directory's clone) over
# every guest log in stress/logs/: per log the kernel booted and the counts of 13 report kinds.
# Output: stress/kernel-report-scan.txt (exit status of the scan appended).
set -u
w=/root/exp/agent-work/co43-ea-send-20261113
python3 -I "$w/project/scripts/kernel-report-scan.py" "$w"/stress/logs/*.log >"$w/stress/kernel-report-scan.txt" 2>&1
echo "exit $?" >>"$w/stress/kernel-report-scan.txt"
tail -n 25 "$w/stress/kernel-report-scan.txt"
