#!/bin/bash
# run-trace.sh <tag> <bzImage> <mesh-tester -s filter>
# Runs guest-kprobe-trace.sh inside the qemu guest (KVM, no monitor) and keeps
# the whole console in logs/phase5/run-<tag>.log. Host side only starts qemu.
set -u
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
TAG="$1"
IMG="$2"
FILTER="$3"
LOG="$F/logs/phase5/run-$TAG.log"
echo "start $(date '+%F %T') $TAG $IMG [$FILTER]"
/root/exp/qca9377-bt-hang/cache/bluez-upstream/tools/test-runner -k "$IMG" -- \
	"$F/guest-kprobe-trace.sh" "$FILTER" > "$LOG" 2>&1
rc=$?
echo "end $(date '+%F %T') rc=$rc"
grep -a -E 'Total:|kprobe NOT added' "$LOG"
