#!/bin/bash
# CO-03's installed-package L2 runs (R300 identity, T201 trigger, T220 control, R310 Noble's PipeWire/WirePlumber) on an image
# Usage: run-inst.sh <image> <run name> <reps>
set -u
B=/root/exp/agent-work/lane5-status-stable-20261114/bluez-572-bundle
T=/root/exp/qca9377-bt-hang/contributions/CO-03-bluez-u12-backport/backport/tests
image=$1 run=$2 reps=$3
mkdir -p "$B/l2runs/$run"
echo "$(date -u '+%F %T') UTC inst $image $run start" >> "$B/logs/progress.log"
docker run --rm --device /dev/kvm \
  -v "$B/asan:/co03/build" -v "$T:/co03/tests:ro" -v "$B/l2runs:/co03/runs" -w "/co03/runs/$run" \
  -e FUNCTIONAL_TESTING_CONTROLLERS=none \
  -e CO03_HOST0_BLUETOOTHD=/usr/libexec/bluetooth/bluetoothd -e CO03_HOST1_BLUETOOTHD=/co03/build/sink/src/bluetoothd \
  -e CO03_VARIANT="$run" -e CO03_RESULTS="/co03/runs/$run/results.jsonl" -e CO03_REPS="$reps" \
  "$image" \
  python3 -B -m pytest -c /co03/tests/pytest.ini --rootdir /co03/tests /co03/tests/l2 \
    --kernel /bluez-kernel/bzImage --bluez-src-dir /co03/build/tools \
    -ra -vv --vm-timeout 90 -p no:cacheprovider \
    -o log_file="/co03/runs/$run/pytest.log" -o log_file_level=0 -k "${4:-r300 or t201 or t220 or r310}" > "$B/l2runs/$run.stdout.log" 2>&1
rc=$?
echo "$(date -u '+%F %T') UTC inst $image $run end rc=$rc: $(tail -n 1 "$B/l2runs/$run.stdout.log")" >> "$B/logs/progress.log"
echo "exit $rc"
