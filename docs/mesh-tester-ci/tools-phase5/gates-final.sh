#!/bin/bash
# gates-final.sh - phase 5 §G: every VM gate on the final sequence with the
# final tester, plus the per-commit preflight of the revised 1/5.
#   kernel  mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03 = 71a4243699c8
#           scratch/with-upstream-leak-fix-on-71a4243699c8 = 64bd2d50f5de (+ local cleanup)
#   tester  cache/bluez-upstream 6640247e6 (ASAN), cache/bluez-noasan 6640247e6 (valgrind)
# Writes logs/phase5/gates-final.log; each run its own run-<tag>.log.
set -u
R=/root/exp/qca9377-bt-hang
F=$R/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5
G=$R/cache/mesh-guest
NB=$R/cache/bluez-noasan
exec > "$L/gates-final.log" 2>&1

build() {
	echo "== build $1 at $2 start $(date '+%F %T')"
	git -C "$G" checkout "$2"
	make -s -C "$G" -f "$MK" kernel-all KTAG="$1" FRAG="$F/frag-fault.config" LOGDIR="$L"
	echo "== build $1 end $(date '+%F %T'): $(tail -n 2 "$L/kernel-build-$1.log" | head -n 1) / $(cat "$F/bzImage-$1.commit")"
}
check() {
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-$1.log" | grep -a -E 'Linux version|Total:|Failed  |Timed out|Not Run |ERROR SUMMARY|LeakSanitizer|leaked in' | cut -c1-110
	"$F/splat-check.sh" "$L/run-$1.log"
}
run() {
	local tag=$1; shift
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" "$@" TAG="$tag" LOGDIR="$L"
	echo "== $tag end $(date '+%F %T')"
	check "$tag"
}

echo "### builds"
make -s -C "$NB" -f "$MK" bluez-make-testers BTAG=noasan-phase5-final2 LOGDIR="$L"
echo "noasan build: $(grep -c -E 'error|warning' "$L/bluez-make-testers-noasan-phase5-final2.log") error/warning lines"
build v3-final-leakfix scratch/with-upstream-leak-fix-on-71a4243699c8
build v3-final mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03

echo "### KVM, ASAN tester"
run p5-G-final-leakfix-kvm run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3-final-leakfix
run p5-G-final-alone-kvm run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3-final
run p5-G-unpatched-kvm run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3base-unpatched
run p5-G-option1-leakfix-kvm run-mesh-kvm-nomon BZIMAGE=$F/bzImage-v3final-leakfix
run p5-G-final-leakfix-mgmt run-mgmt-kvm BZIMAGE=$F/bzImage-v3-final-leakfix
for s in cancel tear-down receiver; do
	echo "== repeat $s start $(date '+%F %T')"
	make -s -C "$F" -f "$MK" run-mesh-repeat TAG=p5-G-repeat-$s STR=$s BZIMAGE=$F/bzImage-v3-final-leakfix LOGDIR="$L"
	echo "== repeat $s end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-p5-G-repeat-$s-summary.txt" | grep 'Total:'
	for i in 1 2 3 4 5; do "$F/splat-check.sh" "$L/run-p5-G-repeat-$s-$i.log" | grep -v '^=='; done
done

echo "### TCG + valgrind, sanitizer-free tester"
for pair in "p5-G-final-leakfix-tcg-valgrind:bzImage-v3-final-leakfix" "p5-G-unpatched-tcg-valgrind:bzImage-v3base-unpatched"; do
	tag=${pair%%:*}
	img=${pair#*:}
	echo "== $tag start $(date '+%F %T')"
	make -s -C "$NB" -f "$MK" run-custom BLUEZ="$NB" BZIMAGE="$F/$img" TAG="$tag" LOGDIR="$L" \
		RUNNER_OPTS="-q $F/qemu-tcg.sh" \
		CMD="valgrind --error-exitcode=65 $NB/tools/mesh-tester -s Send"
	echo "== $tag end $(date '+%F %T')"
	sed -e 's/\x1b\[[0-9;]*m//g' "$L/run-$tag.log" | grep -a -E 'Linux version|Total:|Failed  |Timed out|Not Run |ERROR SUMMARY|definitely lost: [1-9]' | cut -c1-110
	"$F/splat-check.sh" "$L/run-$tag.log"
done

echo "### preflight of the revised 1/5"
FT=$R/cache/full-bt-next
git -C "$FT" checkout --detach 08e90633377f
git -C "$FT" am "$F/series-v3/0001-Bluetooth-MGMT-hand-mesh-transmissions-over-under-hd.patch"
BT_SPARSE="$R/cache/sparse/sparse" "$R/scripts/kernel-preflight.sh" "$FT"
git -C "$FT" branch -f keep/full-bt-next-phase5-v3-final-patch1 HEAD
git -C "$G" checkout mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03
echo "### done $(date '+%F %T')"
