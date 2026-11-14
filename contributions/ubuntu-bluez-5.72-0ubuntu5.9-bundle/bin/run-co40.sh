#!/bin/bash
# CO-40's U29 test (scripts/tests of u29-t1-a2dp-backport, unchanged) in co03-noble-vm:1:
# host0 = asan/<arm>/src/bluetoothd (base = 5.8, bundle), host1 = the base build, ACL held (hold_after_key) or none.
# Usage: run-co40.sh <base|bundle> <run name> <reps> <none|hold_after_key>
set -u
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
U=/root/exp/agent-work/u29-t1-a2dp-backport
arm=$1 name=$2 reps=$3 acl=$4
out=$B/co40/runs/$name
mkdir -p "$out"
echo "arm=$arm host0=asan/$arm reps=$reps acl=$acl" > "$out/commands.txt"
echo "$(date -u '+%F %T') UTC co40 $arm $name start" >> "$B/logs/progress.log"
docker run --rm --device /dev/kvm \
  -v "$B/asan:/co40/build" -v "$U/scripts:/u29/scripts:ro" -v "$B/co40:/co40/out" \
  -w "/co40/out/runs/$name" \
  -e FUNCTIONAL_TESTING_CONTROLLERS=none \
  -e U29_HOST0_BLUETOOTHD="/co40/build/$arm/src/bluetoothd" \
  -e U29_HOST1_BLUETOOTHD=/co40/build/base/src/bluetoothd \
  -e U29_OUT="/co40/out/runs/$name" -e U29_REPS="$reps" -e U29_ACL="$acl" \
  co03-noble-vm:1 \
  python3 -B -m pytest -c /u29/scripts/tests/pytest.ini --rootdir /u29/scripts /u29/scripts/tests/test_u29.py \
    --kernel /bluez-kernel/bzImage --bluez-src-dir /co40/build/tools \
    --btmon -ra -vv --vm-timeout 30 -p no:cacheprovider \
    -o log_file="/co40/out/runs/$name/pytest.log" -o log_file_level=0 > "$out/stdout.log" 2>&1
rc=$?
echo "$(date -u '+%F %T') UTC co40 $arm $name end rc=$rc" >> "$B/logs/progress.log"
echo "exit $rc"
