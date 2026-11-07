#!/bin/sh
# Run PipeWire's VM tests and CO-03's L3 tests in PipeWire's CI image
# (co36-pw-ci:f44) with the BlueZ build build-f44/<variant> in both guests;
# CO-03's own L3 tests put the fixture build (build-f44/sink) on host1.
# The container gets /dev/kvm and nothing else from the host's devices.
# Usage: run-l3.sh <variant> <run name> [pytest args...]
set -eu
top=/root/exp/agent-work/co03
variant=$1
run=$2
shift 2
mkdir -p "$top/runs/$run"
exec docker run --rm \
    --device /dev/kvm \
    -v "$top/pw:/src" \
    -v "$top/tests/l3/test_co03_pw.py:/src/test/bluezenv/test_co03_pw.py:ro" \
    -v "$top/tests/l2/co03_plugins.py:/src/test/bluezenv/co03_plugins.py:ro" \
    -v "$top:/co03" \
    -e CO03_VARIANT="$variant" \
    -e CO03_RUNDIR="/co03/runs/$run" \
    -e CO03_RESULTS="/co03/runs/$run/results.jsonl" \
    -e CO03_REPS="${CO03_REPS:-1}" \
    -e CO03_HOST0_BLUETOOTHD="/co03/build-f44/$variant/src/bluetoothd" \
    -e CO03_HOST1_BLUETOOTHD=/co03/build-f44/sink/src/bluetoothd \
    -w /src \
    co36-pw-ci:f44 \
    /bin/sh /co03/scripts/l3-inside.sh "$@"
