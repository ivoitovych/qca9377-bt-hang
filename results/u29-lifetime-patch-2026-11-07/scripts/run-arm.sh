#!/bin/sh
# One arm, one repetition, in a fresh pair of QEMU/KVM guests (btvirt
# controllers) inside container u29t3-<tree>-<build>-<arm>-<n>.
# Usage: run-arm.sh <master|5.72> <base|patched> <arm A-E,G-J> <n>
# Output: runs/<tree>-<build>-<arm>-<n>/ (pytest.log, dbus-monitor.log,
#         bluetoothd-dut.log, btmon-*.log, events.jsonl, summary.json, command.txt)
set -u
top=/root/exp/agent-work/u29-t3-lifetime-patch
tree=$1
build=$2
arm=$3
n=$4
src=$top/work/$tree-$build
run=$top/runs/$tree-$build-$arm-$n
name=u29t3-$tree-$build-$arm-$n
if [ -e "$run" ]; then
    echo "skip $run (exists)"
    exit 0
fi
mkdir -p "$run"
echo "run-arm.sh $tree $build $arm $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
cat > "$run/command.txt" <<EOF
docker run --rm --name $name --device /dev/kvm -v $top:$top -w $run \\
  -e FUNCTIONAL_TESTING_CONTROLLERS=none -e U29_ARM=$arm -e U29_RUNDIR=$run \\
  -e U29_BLUETOOTHD=$src/src/bluetoothd -e U29_VM_DISCOVERY=$top/scripts/vm_discovery.py \\
  co03-noble-vm:1 python3 -m pytest -c $top/tests/pytest.ini --rootdir $top/tests $top/tests/test_u29t3.py \\
  --kernel /bluez-kernel/bzImage --bluez-src-dir $src -ra -vv --vm-timeout 30 -p no:cacheprovider \\
  -o log_file=$run/pytest.log -o log_file_level=0
EOF
rc=0
docker run --rm --name "$name" \
    --device /dev/kvm \
    -v "$top:$top" -w "$run" \
    -e FUNCTIONAL_TESTING_CONTROLLERS=none \
    -e U29_ARM="$arm" -e U29_RUNDIR="$run" \
    -e U29_BLUETOOTHD="$src/src/bluetoothd" \
    -e U29_VM_DISCOVERY="$top/scripts/vm_discovery.py" \
    co03-noble-vm:1 \
    python3 -m pytest -c "$top/tests/pytest.ini" --rootdir "$top/tests" "$top/tests/test_u29t3.py" \
        --kernel /bluez-kernel/bzImage --bluez-src-dir "$src" \
        -ra -vv --vm-timeout 30 -p no:cacheprovider \
        -o log_file="$run/pytest.log" -o log_file_level=0 \
    > "$run/stdout.log" 2>&1 || rc=$?
echo "run-arm.sh $tree $build $arm $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
exit $rc
