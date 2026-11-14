#!/bin/bash
# CO-03's L2 VM tests (tests/l2 of the dossier, unchanged) in co03-noble-vm:1 against asan/<variant>
# Usage: run-l2.sh <variant: base|bundle> <run name> [pytest args...]   (CO03_REPS = repetitions per test)
set -eu
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
T=/root/exp/qca9377-bt-hang/contributions/CO-03-bluez-u12-backport/backport/tests
variant=$1; run=$2; shift 2
mkdir -p "$B/l2runs/$run"
echo "$(date -u '+%F %T') UTC l2 $variant $run start" >> "$B/logs/progress.log"
set +e
docker run --rm --device /dev/kvm \
  -v "$B/asan:/co03/build" -v "$T:/co03/tests:ro" -v "$B/l2runs:/co03/runs" \
  -w "/co03/runs/$run" \
  -e FUNCTIONAL_TESTING_CONTROLLERS=none \
  -e CO03_HOST0_BLUETOOTHD="/co03/build/$variant/src/bluetoothd" \
  -e CO03_HOST1_BLUETOOTHD=/co03/build/sink/src/bluetoothd \
  -e CO03_VARIANT="$variant" -e CO03_RESULTS="/co03/runs/$run/results.jsonl" -e CO03_REPS="${CO03_REPS:-1}" \
  co03-noble-vm:1 \
  python3 -B -m pytest -c /co03/tests/pytest.ini --rootdir /co03/tests /co03/tests/l2 \
    --kernel /bluez-kernel/bzImage --bluez-src-dir /co03/build/tools \
    -ra -vv --vm-timeout 30 -p no:cacheprovider \
    -o log_file="/co03/runs/$run/pytest.log" -o log_file_level=0 "$@" > "$B/l2runs/$run.stdout.log" 2>&1
rc=$?
echo "$(date -u '+%F %T') UTC l2 $variant $run end rc=$rc: $(tail -n 1 "$B/l2runs/$run.stdout.log")" >> "$B/logs/progress.log"
exit $rc
