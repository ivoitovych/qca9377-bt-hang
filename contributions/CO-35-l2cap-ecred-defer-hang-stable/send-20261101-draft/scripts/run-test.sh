#!/bin/bash
# run-test.sh - refresh 2026-11-01: run l2cap-tester in a QEMU/KVM guest (test-runner, 4 vCPUs) on an image.
# Usage: run-test.sh <image> <log> <limit seconds> exact|all
#   exact: only "L2CAP Ext-Flowctl Server - Accept 2 Close 1" (case-accept2close1.sh)
#   all:   the whole l2cap-tester, no filter
# Refuses to overwrite a log. Prints the case's verdict or HANG, the tester totals, the kernel-report scan.
set -u
IMG=${1:?usage}; LOG=${2:?usage}; LIM=${3:?usage}; MODE=${4:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/co35/refresh-20261101
B=$R/cache/co02-w2c-bluez
TP=$R/cache/co02-bluez/tools/l2cap-tester
CASE="L2CAP Ext-Flowctl Server - Accept 2 Close 1"
[[ -r "$IMG" ]] || { echo "no image $IMG"; exit 2; }
[[ -e "$LOG" ]] && { echo "refusing: $LOG exists"; exit 2; }
case "$MODE" in
exact) cmd=("$W/case-accept2close1.sh") ;;
all) cmd=("$TP") ;;
word:*) cmd=("$TP" -s "${MODE#word:}") ;;
*) echo "mode exact|all|word:<oneword>"; exit 2 ;;
esac
cd "$B" || exit 2
echo "$(date -u '+%F %T') UTC run $(basename "$IMG") $MODE start" >> "$W/progress.log"
echo "start $(date -u '+%F %T') UTC kernel $IMG cpus 4 mode $MODE limit $LIM" > "$LOG"
timeout "$LIM" "$B/tools/test-runner" -q "$R/tmp/mesh-tester-ci/qemu-smp.sh" -k "$IMG" -- "${cmd[@]}" >> "$LOG" 2>&1
rc=$?
echo "exit=$rc end $(date -u '+%F %T') UTC" >> "$LOG"
echo "$(date -u '+%F %T') UTC run $(basename "$IMG") $MODE end rc=$rc" >> "$W/progress.log"
v=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$//' "$LOG" | grep -a -E "^$CASE +.*(Passed|Failed|Not Run|Timed out)" | tr -s ' ')
if [[ $rc -eq 124 ]]; then echo "$(basename "$IMG") [$MODE]: HANG (limit $LIM s)"; else echo "$(basename "$IMG") [$MODE]: ${v:-no verdict for the case, rc=$rc}"; fi
sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$//' "$LOG" | grep -a -E "^(Total|Passed|Failed|Not Run|Timed out):|  (Failed|Timed out|Not Run) " | tr -s ' '
python3 -I "$R/scripts/kernel-report-scan.py" "$LOG"
