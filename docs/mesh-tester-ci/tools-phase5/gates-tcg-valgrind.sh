#!/bin/bash
# gates-tcg-valgrind.sh - phase 5 §G: TCG (no KVM) + valgrind, sanitizer-free
# tester (cache/bluez-noasan at f620a4976), the "Send" cases, on the final
# image and on the unpatched base with the same tester.
set -u
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5
NB=/root/exp/qca9377-bt-hang/cache/bluez-noasan
for pair in "p5-final-leakfix-tcg-valgrind-noasan:bzImage-v3-series-leakfix" "p5-unpatched-tcg-valgrind-noasan:bzImage-v3base-unpatched"; do
	tag=${pair%%:*}
	img=${pair#*:}
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$NB" -f "$MK" run-custom BLUEZ="$NB" BZIMAGE="$F/$img" TAG="$tag" LOGDIR="$L" \
		RUNNER_OPTS="-q $F/qemu-tcg.sh" \
		CMD="valgrind --error-exitcode=65 $NB/tools/mesh-tester -s Send"
	echo "== $tag end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-$tag.log" | grep -a -E 'Linux version|Total:|Failed  |Timed out|Not Run |ERROR SUMMARY|definitely lost|indirectly lost' | cut -c1-120
done
