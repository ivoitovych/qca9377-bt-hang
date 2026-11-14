#!/bin/bash
# finish-logs.sh: the per-kernel totals (summarize.py) and the SHA256SUMS of logs, patches and harness (task 4)
w=/root/exp/agent-work/lane1-btusb-20261114/task4
{
	for s in backlog fix controls lockdep hung; do
		echo "== summary-$s.txt"
		python3 -I "$w/harness/summarize.py" "$w/logs/summary-$s.txt"
	done
} >"$w/logs/totals.txt"
cd "$w/logs" || exit 1
sha256sum runs/* summary-*.txt totals.txt >SHA256SUMS
cd "$w" || exit 1
sha256sum patches/on-co04/*.patch patches/*.txt in/co04.patch co04-message-note.md >patches/SHA256SUMS
cd "$w/harness" || exit 1
sha256sum ./*.py ./*.sh ./*.txt >SHA256SUMS
