#!/bin/sh
# T308, third attempt: as build-wp0417-relaxed.sh, but the flag given as
# the global c_args (the per-subproject -Dwireplumber:c_args of the second
# attempt did not reach the compile line, logs/t308-build-relaxed.log:747).
# It demotes one error class to a warning for every C file; no source change.
# Usage: build-wp0417-relaxed2.sh <log file>
set -eu
w=/root/exp/agent-work/co36
echo "$(date +%H:%M:%S) T308 relaxed2 build start" >> "$w/progress.log"
set +e
docker run --rm --name co36-wp0417-build3 \
    -v "$w/pw-wp0417:/src" \
    -v "$w/ci:/ci:ro" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/build-only-inside.sh build-wp0417-relaxed2-asan \
    -Dc_args=-Wno-error=incompatible-pointer-types > "$1" 2>&1
rc=$?
echo "$(date +%H:%M:%S) T308 relaxed2 build end rc=$rc" >> "$w/progress.log"
exit $rc
