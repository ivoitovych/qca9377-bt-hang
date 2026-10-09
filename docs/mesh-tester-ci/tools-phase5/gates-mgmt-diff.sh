#!/bin/bash
# gates-mgmt-diff.sh - phase 5 §G: mgmt-tester on the unpatched base and a
# second run on the final image, to tell series effects from base/tester ones.
set -u
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5
for pair in "p5-unpatched-mgmt-kvm:bzImage-v3base-unpatched" "p5-final-leakfix-mgmt-kvm-run2:bzImage-v3-series-leakfix"; do
	tag=${pair%%:*}
	img=${pair#*:}
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" run-mgmt-kvm TAG="$tag" BZIMAGE="$F/$img" LOGDIR="$L"
	echo "== $tag end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-$tag.log" | grep -a -E 'Linux version|Total:|Failed  |Timed out|Not Run ' | cut -c1-110
done
