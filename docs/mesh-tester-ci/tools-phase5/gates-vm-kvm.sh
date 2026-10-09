#!/bin/bash
# gates-vm-kvm.sh - phase 5 §G: the KVM gates on the final sequence, one VM at
# a time, with start/end times. Images (tmp/mesh-tester-ci):
#   bzImage-v3-series-leakfix  c4ae5857e5d1 = a4023e09b21d (series) + local cleanup
#   bzImage-v3-series          a4023e09b21d (series alone)
#   bzImage-v3base-unpatched   08e90633377f (bluetooth/master)
# Tester: cache/bluez-upstream f620a4976 (ASAN build).
set -u
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5

run() {
	local tag=$1; shift
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" "$@" TAG="$tag" LOGDIR="$L"
	local rc=$?
	echo "== $tag end $(date '+%F %T') rc=$rc"
	if [ -f "$L/run-$tag.log" ]; then
		make -s -C "$F" -f "$MK" splat-grep TAG="$tag" LOGDIR="$L"
		grep -a -E 'Linux version|Total:' "$L/run-$tag.log" | sed -e 's/\x1b\[[0-9;]*m//g' | cut -c1-110
		echo "   splat lines: $(grep -c -v -E 'FAULT_INJECTION|fail_nth|forcing a failure' "$L/splat-$tag.txt")"
	fi
}

run p5-final-leakfix-kvm-nomon run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3-series-leakfix
run p5-final-series-alone-kvm-nomon run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3-series
run p5-unpatched-kvm-nomon run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3base-unpatched
run p5-final-leakfix-mgmt-kvm run-mgmt-kvm BZIMAGE=$F/bzImage-v3-series-leakfix
for s in cancel tear-down receiver; do
	echo "== repeat $s start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" run-mesh-repeat TAG=p5-final-repeat-$s STR=$s BZIMAGE=$F/bzImage-v3-series-leakfix LOGDIR="$L"
	echo "== repeat $s end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-p5-final-repeat-$s-summary.txt" | grep 'Total:'
done
echo "all done $(date '+%F %T')"
