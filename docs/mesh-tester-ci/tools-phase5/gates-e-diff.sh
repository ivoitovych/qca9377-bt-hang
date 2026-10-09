#!/bin/bash
# gates-e-diff.sh - phase 5 §E: the differential socket-close run, unpatched
# base vs the series (+ local cleanup), under KASAN + lockdep (the "close"
# cases), and the whole mesh-tester under KCSAN + lockdep on both, one VM at
# a time; then the kernel report headers of every log (splat-check.sh).
# Tester: cache/bluez-upstream 6640247e6 (ASAN build).
set -u
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5
run() {
	local tag=$1; shift
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" "$@" TAG="$tag" LOGDIR="$L"
	echo "== $tag end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-$tag.log" | grep -a -E 'Linux version|Total:|Failed  |Timed out|Not Run ' | cut -c1-110
	"$F/splat-check.sh" "$L/run-$tag.log"
}
run p5-e-close-unpatched-kasan run-mesh-kvm-nomon-str STR=close BZIMAGE=$F/bzImage-v3base-unpatched
run p5-e-close-series-kasan run-mesh-kvm-nomon-str STR=close BZIMAGE=$F/bzImage-v3-series-leakfix
run p5-e-all-unpatched-kcsan run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3base-unpatched-kcsan
run p5-e-all-series-kcsan run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3-series-leakfix-kcsan
echo "all done $(date '+%F %T')"
