#!/bin/sh
# Run the CO-03 L2 VM tests (tests/l2) in co03-noble-vm:1.
# host0 runs build/<variant>/src/bluetoothd, host1 the test-fixture build
# (build/sink/src/bluetoothd). The container gets /dev/kvm and nothing
# else from the host's devices: the guests' controllers are btvirt.
# Usage: run-l2.sh <variant> <run name> [pytest args...]
#   CO03_REPS (environment) = repetitions per test (default 1)
# Output: runs/<run name>/{pytest.log,results.jsonl,stdout.log,*.btsnoop}
set -eu
top=/root/exp/agent-work/co03
variant=$1
run=$2
shift 2
mkdir -p "$top/runs/$run"
exec docker run --rm \
    --device /dev/kvm \
    -v "$top:/co03" \
    -w "/co03/runs/$run" \
    -e FUNCTIONAL_TESTING_CONTROLLERS=none \
    -e CO03_HOST0_BLUETOOTHD="/co03/build/$variant/src/bluetoothd" \
    -e CO03_HOST1_BLUETOOTHD=/co03/build/sink/src/bluetoothd \
    -e CO03_VARIANT="$variant" \
    -e CO03_RESULTS="/co03/runs/$run/results.jsonl" \
    -e CO03_REPS="${CO03_REPS:-1}" \
    co03-noble-vm:1 \
    python3 -m pytest -c /co03/tests/pytest.ini --rootdir /co03/tests /co03/tests/l2 \
        --kernel /bluez-kernel/bzImage --bluez-src-dir /co03/build/tools \
        -ra -vv --vm-timeout 30 -p no:cacheprovider \
        -o log_file="/co03/runs/$run/pytest.log" -o log_file_level=0 \
        "$@"
