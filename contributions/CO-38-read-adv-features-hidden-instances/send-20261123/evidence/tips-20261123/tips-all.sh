#!/bin/bash
# tips-all.sh : build-tips.sh, then run-tips.sh, then write the line the btusb stable-line job waits for.
set -u
D=/root/exp/qca9377-bt-hang/tmp/kernel-queue-20261123
"$D/build-tips.sh" || exit 1
"$D/run-tips.sh" || exit 1   # stopped or failed: no done line, so the next job does not start early
echo "$(date -u '+%F %T') UTC suites done (tips2, final)" >> "$KQ_WORK/progress.log"
