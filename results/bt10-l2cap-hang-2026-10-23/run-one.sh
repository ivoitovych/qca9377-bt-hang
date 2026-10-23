#!/bin/bash
# run-one.sh - L2CAP hang: run one l2cap-tester case in a QEMU/KVM guest (test-runner) on a kernel
# image with a short limit, so a hang costs minutes, not the 30 of the full-suite runner.
# Usage: run-one.sh <image> <log> <limit seconds> <cpus 1|4> "<case name>"
# Refuses to overwrite a log. Prints the case's verdict line, or HANG when the limit was hit.
set -u
IMG=${1:?usage}; LOG=${2:?usage}; LIM=${3:?usage}; CPUS=${4:?usage}; CASE=${5:?usage}
R=/root/exp/qca9377-bt-hang
B=$R/cache/co02-w2c-bluez
TP=$R/cache/co02-bluez/tools/l2cap-tester
[[ -r "$IMG" ]] || { echo "no image $IMG"; exit 2; }
[[ -e "$LOG" ]] && { echo "refusing: $LOG exists"; exit 2; }
opts=()
if [[ "$CPUS" == 4 ]]; then opts+=(-q "$R/tmp/mesh-tester-ci/qemu-smp.sh"); fi
cd "$B" || exit 2
echo "start $(date -u '+%T') kernel $IMG cpus $CPUS case $CASE limit $LIM" > "$LOG"
timeout "$LIM" "$B/tools/test-runner" "${opts[@]}" -k "$IMG" -- "$TP" -s "$CASE" >> "$LOG" 2>&1
rc=$?
echo "exit=$rc end $(date -u '+%T')" >> "$LOG"
v=$(grep -a -E "^$CASE +.*(Passed|Failed|Not Run|Timed out)" "$LOG" | sed -e 's/\x1b\[[0-9;]*m//g' | tr -s ' ')
if [[ $rc -eq 124 ]]; then echo "$(basename "$IMG"): HANG (limit $LIM s)"; else echo "$(basename "$IMG"): ${v:-no verdict, rc=$rc}"; fi
