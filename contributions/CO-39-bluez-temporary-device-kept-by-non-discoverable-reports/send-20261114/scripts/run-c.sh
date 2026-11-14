#!/bin/sh
# The patch's own functional test (test/functional/test_device.py, from work/master-patched) against the
# bluetoothd/tools built in work/<build>, in the noble VM container (its baked-in kernel, /bluez-kernel/bzImage).
# Usage: run-c.sh <master-base|master-patched> <n> <target>...
#   <target> is relative to work/master-patched/test/functional
# Output: runs/<build>-<n>/ (command.txt, stdout.log, pytest.log)
set -u
top=/root/exp/agent-work/lane4-bluez-20261114/co39
build=$1
n=$2
shift 2
src=$top/work/$build
suite=$top/work/master-patched
run=$top/runs/$build-$n
name=lane4-co39-$build-$n
if [ -e "$run" ]; then
    echo "skip $run (exists)"
    exit 0
fi
mkdir -p "$run"
targets=""
for t in "$@"; do
    targets="$targets $suite/test/functional/$t"
done
echo "run-c.sh $build $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
cat > "$run/command.txt" <<EOF
docker run --rm --name $name --device /dev/kvm -v $top:$top -w $run \\
  -e FUNCTIONAL_TESTING_CONTROLLERS=none \\
  co03-noble-vm:1 python3 -m pytest -c $suite/test/pytest.ini --rootdir $suite/test $targets \\
  --kernel /bluez-kernel/bzImage --bluez-src-dir $src -ra -vv -p no:cacheprovider \\
  -o log_file=$run/pytest.log -o log_file_level=0
EOF
rc=0
# shellcheck disable=SC2086
docker run --rm --name "$name" \
    --device /dev/kvm \
    -v "$top:$top" -w "$run" \
    -e FUNCTIONAL_TESTING_CONTROLLERS=none \
    co03-noble-vm:1 \
    python3 -m pytest -c "$suite/test/pytest.ini" --rootdir "$suite/test" $targets \
        --kernel /bluez-kernel/bzImage --bluez-src-dir "$src" \
        -ra -vv -p no:cacheprovider \
        -o log_file="$run/pytest.log" -o log_file_level=0 \
    > "$run/stdout.log" 2>&1 || rc=$?
echo "run-c.sh $build $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
exit $rc
