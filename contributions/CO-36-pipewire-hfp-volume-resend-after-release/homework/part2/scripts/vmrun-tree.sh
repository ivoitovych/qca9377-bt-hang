#!/bin/sh
# As vmrun.sh, for another tree of agent-work/co36 and build dir (T308:
# pw-wp0417, build-wp0417-relaxed2-asan).  Only /dev/kvm is passed.
# Usage: vmrun-tree.sh <tree dir name> <build dir name> <run id> <repeat count> [pytest args...]
set -eu

tree=$1
build=$2
run=$3
rep=$4
shift 4

w=/root/exp/agent-work/co36
t=test_co36_hfp_volume_resend.py

echo "$(date +%H:%M:%S) $run start ($tree/$build): $*" >> "$w/progress.log"
set +e
docker run --rm --name "co36-$run" \
    --device /dev/kvm \
    -e CO36_RUN="$run" \
    -e CO36_REPEAT="$rep" \
    -v "$w/$tree:/src" \
    -v "$w/tests/$t:/src/test/bluezenv/$t:ro" \
    -v "$w/ci:/ci:ro" \
    -v "$w/results:/out" \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /ci/bluez-tests-inside.sh "$build" "$@" > "$w/logs/$run.log" 2>&1
rc=$?
echo "$(date +%H:%M:%S) $run end rc=$rc" >> "$w/progress.log"
exit $rc
