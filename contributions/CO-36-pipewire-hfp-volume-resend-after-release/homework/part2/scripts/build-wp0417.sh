#!/bin/sh
# T308: builds agent-work/co36/pw-wp0417 (PipeWire master 4cfc4711 with
# WirePlumber 0.4.17 as subproject) with CI's bluez_tests options.
# Usage: build-wp0417.sh <log file>
set -eu
w=/root/exp/agent-work/co36
echo "$(date +%H:%M:%S) T308 build start" >> "$w/progress.log"
set +e
docker run --rm --name co36-wp0417-build \
    -v "$w/pw-wp0417:/src" \
    -v "$w/ci:/ci:ro" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/build-only-inside.sh build-wp0417-asan > "$1" 2>&1
rc=$?
echo "$(date +%H:%M:%S) T308 build end rc=$rc" >> "$w/progress.log"
exit $rc
