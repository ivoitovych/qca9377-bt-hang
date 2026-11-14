#!/bin/bash
# chain-co20.sh: after the CO-21 usbip batch, the bot run on the CO-21 mails (it boots guests too) and the
# co20 build, the CO-20 scenarios (base vs patched): one guest at a time
w=/root/exp/agent-work/lane1-btusb-20261114
until grep -q "ALL DONE" "$w/task3/project/tmp/bot-ci-local/co21-20261114/summary.txt" 2>/dev/null; do sleep 30; done
until [ -e "$w/img/bzImage-co20.commit" ]; do sleep 20; done
"$w/task3/harness/run-batch-usbip.sh" "$w/task3/harness/spec-co20.txt" "$w/task3/logs/summary-co20.txt"
echo chain done
