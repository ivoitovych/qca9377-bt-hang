#!/bin/sh
# One arm, one repetition, in a fresh pair of QEMU/KVM guests (btvirt
# controllers) inside container u29t2-<arm>-<n>.
# Usage: run-arm.sh <A|B|C|D> <n>
# Output: runs/<arm>-<n>/ (pytest.log, dbus-monitor.log, bluetoothd-dut.log,
#         btmon-dut.log, *.btsnoop, events.jsonl, summary.json, command.txt)
set -eu
top=/root/exp/agent-work/u29-t2-temporary-lifetime
arm=$1
n=$2
run=$top/runs/$arm-$n
mkdir -p "$run"
echo "$0 $arm $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
cat > "$run/command.txt" <<EOF
docker run --rm --name u29t2-$arm-$n --device /dev/kvm -v $top:$top -w $run \\
  -e FUNCTIONAL_TESTING_CONTROLLERS=none -e U29_ARM=$arm -e U29_RUNDIR=$run \\
  -e U29_BLUETOOTHD=$top/src/bluez-5.72/src/bluetoothd -e U29_VM_DISCOVERY=$top/scripts/vm_discovery.py \\
  co03-noble-vm:1 python3 -m pytest -c $top/tests/pytest.ini --rootdir $top/tests $top/tests/test_u29.py \\
  --kernel /bluez-kernel/bzImage --bluez-src-dir $top/src/bluez-5.72 -ra -vv --vm-timeout 30 -p no:cacheprovider \\
  -o log_file=$run/pytest.log -o log_file_level=0
EOF
rc=0
docker run --rm --name "u29t2-$arm-$n" \
    --device /dev/kvm \
    -v "$top:$top" -w "$run" \
    -e FUNCTIONAL_TESTING_CONTROLLERS=none \
    -e U29_ARM="$arm" -e U29_RUNDIR="$run" \
    -e U29_BLUETOOTHD="$top/src/bluez-5.72/src/bluetoothd" \
    -e U29_VM_DISCOVERY="$top/scripts/vm_discovery.py" \
    co03-noble-vm:1 \
    python3 -m pytest -c "$top/tests/pytest.ini" --rootdir "$top/tests" "$top/tests/test_u29.py" \
        --kernel /bluez-kernel/bzImage --bluez-src-dir "$top/src/bluez-5.72" \
        -ra -vv --vm-timeout 30 -p no:cacheprovider \
        -o log_file="$run/pytest.log" -o log_file_level=0 \
    > "$run/stdout.log" 2>&1 || rc=$?
echo "$0 $arm $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
exit $rc
