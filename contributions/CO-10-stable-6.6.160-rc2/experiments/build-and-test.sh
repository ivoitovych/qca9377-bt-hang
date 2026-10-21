#!/bin/bash
# build-and-test.sh - CO-10: 6.6.160-rc2 against 6.6.159 in QEMU (KVM, 4 CPUs).
#
# Builds both kernels in cache/stable-6.6.y with BlueZ's doc/tester.config
# (KASAN, PROVE_LOCKING, DEBUG_ATOMIC_SLEEP, as the BlueZ CI bot), then runs, on
# each, with BlueZ's tools/test-runner from cache/bluez-bt9 (master 7428ca2df +
# the leak fix + the simultaneous-discovery test series, as applied upstream):
#   - mgmt-tester -s "Simultaneous" three times (BT-9's race case and its control);
#   - mgmt-tester -p "Start Discovery" and -p "Stop Discovery" once each;
#   - the full mgmt-tester once;
#   - patches/kernel/repro-mgmt-flush-status.py twice (BT-8's reproducer).
# Then greps every log for kernel splats and writes summary.txt.
#
# Usage: build-and-test.sh <out-dir>     (the directory must not exist)
# Runs in the foreground for about an hour; nothing is installed or loaded on
# the host: the kernels run only inside QEMU guests.
set -u
OUT=${1:?usage: build-and-test.sh <out-dir>}
[[ -e "$OUT" ]] && { echo "refusing: $OUT exists"; exit 2; }
mkdir -p "$OUT"

REPO=/root/exp/qca9377-bt-hang
TREE=$REPO/cache/stable-6.6.y
BLUEZ=$REPO/cache/bluez-bt9
MK=$REPO/tmp/mesh-tester-ci/build.mk
IMG=$REPO/tmp/mesh-tester-ci
QEMU=$REPO/tmp/mesh-tester-ci/qemu-smp.sh
REPRO=$REPO/patches/kernel/repro-mgmt-flush-status.py
RC=c578c158a36845a2b642bd491adaa7e4a479e04f      # Linux 6.6.160-rc2 (linux-stable-rc)
BASE=v6.6.159

exec > >(tee -a "$OUT/run.log") 2>&1
echo "start $(date -u '+%F %T') UTC"
echo "toolchain: $(gcc --version | head -n 1)"
echo "qemu: $(qemu-system-x86_64 --version | head -n 1)"
echo "bluez tree: $(git -C "$BLUEZ" log -1 --format='%H %s')"
sha256sum "$BLUEZ/tools/mgmt-tester" "$BLUEZ/tools/test-runner" "$REPRO"

build() {
	local tag=$1 rev=$2
	echo "== build $tag ($rev) $(date -u '+%T')"
	git -C "$TREE" checkout -q --detach "$rev" || { echo "checkout failed"; return 1; }
	echo "   HEAD $(git -C "$TREE" log -1 --format='%H %s')"
	make -C "$TREE" -f "$MK" kernel-all KTAG="$tag" BLUEZ="$BLUEZ" LOGDIR="$OUT"
	local rc=$?
	echo "== build $tag end $(date -u '+%T') rc=$rc"
	sha256sum "$IMG/bzImage-$tag" "$IMG/config-$tag"
	return $rc
}

run() {
	local tag=$1 name=$2; shift 2
	local log="$OUT/$tag.$name.log"
	echo "-- $tag $name $(date -u '+%T')"
	( cd "$BLUEZ" && timeout 3600 tools/test-runner -q "$QEMU" -k "$IMG/bzImage-$tag" -- "$@" ) >"$log" 2>&1
	echo "   exit=$?  $(grep -a -E 'Total: ' "$log" | tail -n 1)"
}

for k in "co10-6.6.160-rc2 $RC" "co10-6.6.159 $BASE"; do
	set -- $k
	build "$1" "$2" || { echo "build of $1 failed; stopping"; exit 1; }
done

for tag in co10-6.6.160-rc2 co10-6.6.159; do
	for i in 1 2 3; do
		run "$tag" "simult-$i" "$BLUEZ/tools/mgmt-tester" -s "Simultaneous"
	done
	run "$tag" "start-discovery" "$BLUEZ/tools/mgmt-tester" -p "Start Discovery"
	run "$tag" "stop-discovery" "$BLUEZ/tools/mgmt-tester" -p "Stop Discovery"
	run "$tag" "mgmt-full" "$BLUEZ/tools/mgmt-tester"
	for i in 1 2; do
		run "$tag" "flush-$i" /usr/bin/python3 -I "$REPRO"
	done
done

{
	echo "# CO-10 summary, $(date -u '+%F %T') UTC"
	for f in "$OUT"/co10-*.log; do
		echo "## $(basename "$f")"
		grep -a -E 'Simultaneous|Total: |PATCHED:|BUG REPRODUCED|DID NOT HIT|Linux version' "$f"
		grep -a -c -E 'BUG:|KASAN|WARNING:|possible circular|possible recursive|inconsistent lock|sleeping function' "$f" | sed 's/^/splat lines: /'
	done
} > "$OUT/summary.txt"
sha256sum "$OUT"/*.log > "$OUT/SHA256SUMS"
echo "done $(date -u '+%F %T') UTC"
