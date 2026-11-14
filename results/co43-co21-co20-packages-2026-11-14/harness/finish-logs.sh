#!/bin/bash
# finish-logs.sh: logs/metrics.txt and SHA256SUMS for the logs, the packages, the series and the harness (task 3)
w=/root/exp/agent-work/lane1-btusb-20261114/task3
python3 -I "$w/harness/metrics.py" "$w"/logs/runs/*.log >"$w/logs/metrics.txt"
cd "$w/logs" || exit 1
sha256sum runs/* summary-*.txt metrics.txt verifyfixes-full-*.txt >SHA256SUMS
cd "$w" || exit 1
sha256sum step1/series/*.patch step2/out/*.patch step3/out/*.patch co21-package/* co20-package/* >SHA256SUMS
cd "$w/harness" || exit 1
sha256sum ./*.py ./*.sh ./*.txt >SHA256SUMS
cd "$w/project/tmp/bot-ci-local" || exit 1
find co21-20261114 co20-20261114 -type f -print0 | xargs -0 sha256sum >"$w/logs/SHA256SUMS-bot"
