#!/bin/bash
# all-gaps.sh : build-next2.sh, run-gaps.sh, bot-co38.sh, one after the other (no two loads at once, so no guest
# runs against a container build). The final line "ALL GAPS DONE" is written only when every stage returned.
set -u
D=/root/exp/qca9377-bt-hang/tmp/kernel-queue-20261126
L=<work area>/tips3/progress.log
mkdir -p "$(dirname "$L")"
"$D/build-next2.sh" || { echo "$(date -u '+%F %T') UTC STOPPED at build" >> "$L"; exit 1; }
"$D/run-gaps.sh" || { echo "$(date -u '+%F %T') UTC STOPPED at runs" >> "$L"; exit 1; }
"$D/bot-co38.sh" || { echo "$(date -u '+%F %T') UTC STOPPED at bot" >> "$L"; exit 1; }
echo "$(date -u '+%F %T') UTC ALL GAPS DONE" >> "$L"
