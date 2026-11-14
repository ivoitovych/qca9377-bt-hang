#!/bin/bash
# make-sums.sh : SHA256SUMS of the run logs, the images' commit files, the mails and the proposals
W=/root/exp/agent-work/lane7-sco-20261114
cd "$W" || exit 1
sha256sum logs/run-*.log logs/checkpatch.txt img/*.commit proposal/* $(find mails -type f) abort-reason-audit.txt cancel-sync-analysis.txt OPERATOR-NOTES.txt park.diff park-early.diff > SHA256SUMS
wc -l SHA256SUMS
