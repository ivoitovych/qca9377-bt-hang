#!/bin/sh
# Runs PipeWire's Bluetooth VM tests plus the CO-36 test file of this work
# area on the co36 copy of master 4cfc4711 (build-v0-asan), the way the
# homework's ci/bluez-tests.sh does.
# The container gets /dev/kvm and nothing else from the host's devices:
# no USB, not privileged; tests never use hw=True or --force-usb.
# Usage: vmrun.sh <run id> <repeat count> [pytest args...]
# Output: logs/<run id>.log (pytest stdout), results/<run id>-results.jsonl,
#         results/<run id>-pytest-log.txt (every log record)
set -eu

run=$1
rep=$2
shift 2

w=/root/exp/agent-work/co36
t=test_co36_hfp_volume_resend.py

echo "$(date +%H:%M:%S) $run start: $*" >> "$w/progress.log"
set +e
docker run --rm --name "co36-$run" \
    --device /dev/kvm \
    -e CO36_RUN="$run" \
    -e CO36_REPEAT="$rep" \
    -v "$w/pw:/src" \
    -v "$w/tests/$t:/src/test/bluezenv/$t:ro" \
    -v "$w/ci:/ci:ro" \
    -v "$w/results:/out" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/bluez-tests-inside.sh build-v0-asan "$@" > "$w/logs/$run.log" 2>&1
rc=$?
echo "$(date +%H:%M:%S) $run end rc=$rc" >> "$w/progress.log"
exit $rc
