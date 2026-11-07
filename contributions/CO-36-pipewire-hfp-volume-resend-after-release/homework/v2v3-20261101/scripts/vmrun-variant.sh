#!/bin/sh
# L2: PipeWire's Bluetooth VM tests with the homework's CO-36 test file
# (unchanged, read-only) on one variant tree of this work area.
# The container gets /dev/kvm and no other device (no USB, not privileged);
# no test uses hw=True or --force-usb. No core files: --ulimit core=0 here,
# ulimit -c 0 and ASan disable_coredump=1 in ci/bluez-tests-inside.sh, and
# ci/env-nocore.py mounted over pytest-bluezenv's env.py for the VMs.
# Usage: vmrun-variant.sh <v0|v2|v3> <run id> <repeat count> [pytest args...]
# Output: logs/<run id>.log, results/<run id>-results.jsonl, results/<run id>-pytest-log.txt
set -eu

v=$1
run=$2
rep=$3
shift 3

W=/root/exp/agent-work/co36-v2v3-20261101
T=/root/exp/qca9377-bt-hang/contributions/CO-36-pipewire-hfp-volume-resend-after-release/homework/tests/test_co36_hfp_volume_resend.py
P=/usr/local/lib64/python3.14/site-packages/pytest_bluezenv/env.py

echo "$(date +%H:%M:%S) $run ($v) start: $*" >> "$W/progress.log"
echo "# $run variant $v tree $W/pw-$v backend-native.c $(sha256sum "$W/pw-$v/spa/plugins/bluez5/backend-native.c")" > "$W/logs/$run.log"
echo "# test file $(sha256sum "$T")" >> "$W/logs/$run.log"
set +e
docker run --rm --name "co36v2v3-$run" \
    --device /dev/kvm \
    --ulimit core=0 \
    -e CO36_RUN="$run" \
    -e CO36_REPEAT="$rep" \
    -v "$W/pw-$v:/src" \
    -v "$T:/src/test/bluezenv/test_co36_hfp_volume_resend.py:ro" \
    -v "$W/ci/env-nocore.py:$P:ro" \
    -v "$W/ci:/ci:ro" \
    -v "$W/results:/out" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/bluez-tests-inside.sh build-v0-asan "$@" >> "$W/logs/$run.log" 2>&1
rc=$?
echo "$(date +%H:%M:%S) $run ($v) end rc=$rc" >> "$W/progress.log"
exit $rc
