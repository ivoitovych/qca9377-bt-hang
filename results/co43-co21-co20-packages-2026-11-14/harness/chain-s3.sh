#!/bin/bash
# chain-s3.sh: once the s3 image (E + A, B2, D v2, BT-24, BT-25) is built, the runtime matrix on it
w=/root/exp/agent-work/lane1-btusb-20261114
until [ -e "$w/img/bzImage-s3.commit" ]; do sleep 20; done
"$w/task3/harness/run-batch.sh" "$w/task3/harness/spec-s3-matrix.txt" "$w/task3/logs/summary-s3-matrix.txt"
echo chain done
