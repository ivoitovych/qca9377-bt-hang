#!/bin/sh
# Task C: run tests of BlueZ's own functional suite (work/master-test, the
# test/functional tree at a80671987 plus the candidate test) against the
# bluetoothd/tools built in work/master-<build>, in a container, with the
# suite's own test/pytest.ini and rootdir.
# Usage: run-c-v2.sh <base|patched> <tag> <n> <target>...
#   <target> is a path relative to work/master-test/test/functional, e.g.
#   test_device.py or test_agent.py::test_agent_pair_bredr
# Output: runs-v2/C-<tag>-<build>-<n>/
set -u
top=/root/exp/agent-work/u29-t3-lifetime-patch
build=$1
tag=$2
n=$3
shift 3
src=$top/work/master-$build
suite=$top/work/master-test
run=$top/runs-v2/C-$tag-$build-$n
name=u29v2-C-$tag-$build-$n
if [ -e "$run" ]; then
    echo "skip $run (exists)"
    exit 0
fi
mkdir -p "$run"
targets=""
for t in "$@"; do
    targets="$targets $suite/test/functional/$t"
done
echo "run-c-v2.sh $build $tag $n  (start $(date +%H:%M:%S))" >> "$top/PROGRESS.log"
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
echo "run-c-v2.sh $build $tag $n  (end $(date +%H:%M:%S), exit $rc)" >> "$top/PROGRESS.log"
exit $rc
