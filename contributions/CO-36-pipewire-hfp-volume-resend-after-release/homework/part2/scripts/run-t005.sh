#!/bin/sh
# T005: PipeWire's meson test suite on master 4cfc4711 (the co36 copy of
# the tree), CI build_on_fedora options, in co36-pw-ci:f44.
# Only /dev/kvm is passed (not even needed here); no USB, not privileged.
# Usage: run-t005.sh <log file>
set -eu
log=$1
w=/root/exp/agent-work/co36
echo "$(date +%H:%M:%S) T005 start" >> "$w/progress.log"
set +e
docker run --rm --name co36-t005 \
    --device /dev/kvm \
    -v "$w/pw:/src" \
    -v "$w/ci:/ci:ro" \
    -v "$w/results:/out" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/t005-inside.sh > "$log" 2>&1
rc=$?
echo "$(date +%H:%M:%S) T005 end rc=$rc" >> "$w/progress.log"
exit $rc
