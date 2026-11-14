#!/bin/bash
# chain-s3f.sh: after the s3 matrix and the s3f build, one run of each scenario on s3f
# (s3f = s3 with the braces of an if/else balanced for checkpatch; no other change)
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "^batch:" "$w/task3/logs/summary-s3-matrix.txt" 2>/dev/null; do sleep 20; done
until [ -e "$w/img/bzImage-s3f.commit" ]; do sleep 20; done
"$w/task3/harness/run-batch.sh" "$w/task3/harness/spec-s3f-sample.txt" "$w/task3/logs/summary-s3f-sample.txt"
echo chain done
