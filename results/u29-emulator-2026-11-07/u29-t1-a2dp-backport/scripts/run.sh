#!/bin/sh
# Run one arm of the U29 test in co03-noble-vm:1 (QEMU/KVM guests, btvirt
# controllers; only /dev/kvm is passed in).
# Usage: run.sh <baseline|patched> [run name [reps [none|hold]]]
#   reps default 5; ACL mode none, or hold = an unsecured ACL (L2CAP PSM 1)
#   is held open before Connect()
# host0 runs src/bluez-5.72-<arm>/src/bluetoothd; host1 (the peer) always the
# baseline build. Output: runs/<arm>[-name]/ (rep-N/, results.jsonl, pytest.log,
# stdout.log, commands.txt).
set -eu
top=/root/exp/agent-work/u29-t1-a2dp-backport
arm=$1
name=${2:-$arm}
U29_REPS=${3:-${U29_REPS:-5}}
U29_ACL=${4:-${U29_ACL:-none}}
case $arm in
baseline) h0=bluez-5.72-base ;;
patched) h0=bluez-5.72-patched ;;
*) echo "arm: baseline or patched" >&2; exit 2 ;;
esac
out=$top/runs/$name
mkdir -p "$out"
echo "arm=$arm host0=$h0 reps=${U29_REPS:-5} acl=${U29_ACL:-none}" > "$out/commands.txt"
echo "run.sh $arm $name" >> "$out/commands.txt"
echo "$(date +%H:%M:%S) start $arm $name" >> "$top/PROGRESS.log"
set +e
docker run --rm --name "u29t1-$name" \
    --device /dev/kvm \
    -v "$top:/u29" \
    -w "/u29/runs/$name" \
    -e FUNCTIONAL_TESTING_CONTROLLERS=none \
    -e U29_HOST0_BLUETOOTHD="/u29/src/$h0/src/bluetoothd" \
    -e U29_HOST1_BLUETOOTHD=/u29/src/bluez-5.72-base/src/bluetoothd \
    -e U29_OUT="/u29/runs/$name" \
    -e U29_REPS="${U29_REPS:-5}" \
    -e U29_ACL="${U29_ACL:-none}" \
    co03-noble-vm:1 \
    python3 -m pytest -c /u29/scripts/tests/pytest.ini --rootdir /u29/scripts \
        /u29/scripts/tests/test_u29.py \
        --kernel /bluez-kernel/bzImage --bluez-src-dir /u29/src/bluez-5.72-tools \
        --btmon -ra -vv --vm-timeout 30 -p no:cacheprovider \
        -o log_file="/u29/runs/$name/pytest.log" -o log_file_level=0 \
    > "$out/stdout.log" 2>&1
rc=$?
echo "$(date +%H:%M:%S) end $arm $name rc=$rc" >> "$top/PROGRESS.log"
echo "exit $rc"
exit $rc
