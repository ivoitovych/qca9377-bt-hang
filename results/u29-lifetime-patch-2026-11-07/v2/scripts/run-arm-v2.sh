#!/bin/sh
# Round 2: one arm, one repetition, in a fresh pair of QEMU/KVM guests (btvirt
# controllers) inside container u29v2-<tree>-<build>-<arm>-<n>.
# Usage: run-arm-v2.sh <master> <base|patched> <arm P1|P2|BNF|GNF|GDL> <n>
# Output: runs-v2/<tree>-<build>-<arm>-<n>/
set -u
top=/root/exp/agent-work/u29-t3-lifetime-patch
tree=$1
build=$2
arm=$3
n=$4
src=$top/work/$tree-$build
run=$top/runs-v2/$tree-$build-$arm-$n
name=u29v2-$tree-$build-$arm-$n
if [ -e "$run" ]; then
    echo "skip $run (exists)"
    exit 0
fi
mkdir -p "$run"
echo "run-arm-v2.sh $tree $build $arm $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
cat > "$run/command.txt" <<EOF
docker run --rm --name $name --device /dev/kvm -v $top:$top -w $run \\
  -e FUNCTIONAL_TESTING_CONTROLLERS=none -e U29_ARM=$arm -e U29_RUNDIR=$run \\
  -e U29_BLUETOOTHD=$src/src/bluetoothd -e U29_VM_DISCOVERY=$top/scripts/vm_discovery.py \\
  co03-noble-vm:1 python3 -m pytest -c $top/tests_v2/pytest.ini --rootdir $top/tests_v2 $top/tests_v2/test_u29v2.py \\
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
    python3 -m pytest -c "$top/tests_v2/pytest.ini" --rootdir "$top/tests_v2" "$top/tests_v2/test_u29v2.py" \
        --kernel /bluez-kernel/bzImage --bluez-src-dir "$src" \
        -ra -vv --vm-timeout 30 -p no:cacheprovider \
        -o log_file="$run/pytest.log" -o log_file_level=0 \
    > "$run/stdout.log" 2>&1 || rc=$?
echo "run-arm-v2.sh $tree $build $arm $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
exit $rc
