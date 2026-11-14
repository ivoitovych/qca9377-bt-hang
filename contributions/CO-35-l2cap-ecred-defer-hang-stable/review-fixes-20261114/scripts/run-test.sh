#!/bin/bash
# run-test.sh <image> <log> <limit s> exact|all   (copy of CO-35 refresh's run-test.sh; paths to this work area;
# the guest runs at low priority: nice -n 10 ionice -c 2 -n 7). One l2cap-tester in a test-runner guest, 4 vCPUs.
set -u
IMG=${1:?usage}; LOG=${2:?usage}; LIM=${3:?usage}; MODE=${4:?usage}
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
B=$R/cache/co02-w2c-bluez
TP=$R/cache/co02-bluez/tools/l2cap-tester
CASE="L2CAP Ext-Flowctl Server - Accept 2 Close 1"
[[ -r "$IMG" ]] || { echo "no image $IMG"; exit 2; }
[[ -e "$LOG" ]] && { echo "refusing: $LOG exists"; exit 2; }
case "$MODE" in
exact) cmd=("$W/scripts/case-accept2close1.sh") ;;
all) cmd=("$TP") ;;
*) echo "mode exact|all"; exit 2 ;;
esac
cd "$B" || exit 2
echo "$(date -u '+%F %T') UTC run $(basename "$IMG") $MODE start" >> "$W/progress.log"
echo "start $(date -u '+%F %T') UTC kernel $IMG cpus 4 mode $MODE limit $LIM" > "$LOG"
nice -n 10 ionice -c 2 -n 7 timeout "$LIM" "$B/tools/test-runner" -q "$R/tmp/mesh-tester-ci/qemu-smp.sh" -k "$IMG" -- "${cmd[@]}" >> "$LOG" 2>&1
rc=$?
echo "exit=$rc end $(date -u '+%F %T') UTC" >> "$LOG"
echo "$(date -u '+%F %T') UTC run $(basename "$IMG") $MODE end rc=$rc" >> "$W/progress.log"
v=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$//' "$LOG" | grep -a -E "^$CASE +.*(Passed|Failed|Not Run|Timed out)" | tr -s ' ')
if [[ $rc -eq 124 ]]; then echo "$(basename "$IMG") [$MODE]: HANG (limit $LIM s)"; else echo "$(basename "$IMG") [$MODE]: ${v:-no verdict for the case, rc=$rc}"; fi
sed -e 's/\x1b\[[0-9;]*m//g' -e 's/\r$//' "$LOG" | grep -a -E "^(Total|Passed|Failed|Not Run|Timed out):|  (Failed|Timed out|Not Run) " | tr -s ' '
python3 -I "$R/scripts/kernel-report-scan.py" "$LOG"
