#!/bin/bash
# chain-co20-rerun.sh: after the bot run on the CO-20 mails (it boots guests), the CO-20 reruns
# (the base rx-cycles-2 run that lost its emulator socket; rx-unknown with the relaxed judge)
w=/root/exp/agent-work/lane1-btusb-20261114/task3
until grep -q "ALL DONE" "$w/project/tmp/bot-ci-local/co20-20261114/summary.txt" 2>/dev/null; do sleep 30; done
"$w/harness/run-batch-usbip.sh" "$w/harness/spec-co20-rerun.txt" "$w/logs/summary-co20-rerun.txt"
echo chain done
