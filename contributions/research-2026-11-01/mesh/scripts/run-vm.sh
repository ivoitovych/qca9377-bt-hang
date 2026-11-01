#!/bin/bash
# run-vm.sh <tag> <image-tag> <tester> [tester args...]
# One QEMU guest (BlueZ test-runner, 4 CPUs through the project's
# tmp/mesh-tester-ci/qemu-smp.sh, 2 GB), kernel img/bzImage-<image-tag>.
# Log: logs/<tag>.log (refuses to overwrite). Only one guest at a time:
# a lock file in this area serialises the calls.
set -u
R=/root/exp/agent-work/research-mesh
SMPW=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/qemu-smp.sh
SCAN=/root/exp/qca9377-bt-hang/scripts/kernel-report-scan.py
TAG="${1:?tag}"
IMG="${2:?image tag}"
shift 2
export QEMU_SMP=4
mkdir -p "$R/logs"
LOG=$R/logs/$TAG.log
if [ -e "$LOG" ]; then
	echo "== $TAG exists, skipped"
	exit 0
fi
exec 9> "$R/vm.lock"
flock 9
echo "== vm $TAG start $(date '+%F %T') image $IMG: $*" | tee -a "$R/progress.log"
"$R/bin/test-runner" -q "$SMPW" -o -m -o 2G -k "$R/img/bzImage-$IMG" -- "$@" > "$LOG" 2>&1
rc=$?
echo "== vm $TAG end $(date '+%F %T') rc=$rc" | tee -a "$R/progress.log"
sed -e 's/\x1b\[[0-9;]*m//g' "$LOG" | grep -a -E 'Linux version|Total:|ADV-DUR|smp: Brought up| (Passed|Failed|Timed out|Not Run) +[0-9.]+ seconds' | cut -c1-160
python3 -I "$SCAN" "$LOG" | tail -n 2
exit $rc
