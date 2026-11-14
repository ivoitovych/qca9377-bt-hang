#!/bin/bash
# chain-co21.sh: after the s3f sample batch and the co21 build, the 5 usbip scenarios twice, base vs patched
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "^batch:" "$w/task3/logs/summary-s3f-sample.txt" 2>/dev/null; do sleep 20; done
until [ -e "$w/img/bzImage-co21.commit" ]; do sleep 20; done
"$w/task3/harness/run-batch-usbip.sh" "$w/task3/harness/spec-co21.txt" "$w/task3/logs/summary-co21.txt"
echo chain done
