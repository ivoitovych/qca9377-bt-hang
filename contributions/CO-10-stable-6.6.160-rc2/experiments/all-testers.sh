#!/bin/bash
# all-testers.sh - CO-10: every BlueZ tester the CI bot runs (TestRunner_*),
# on 6.6.160-rc2 and on 6.6.159, in QEMU (KVM, 4 CPUs), with the kernels
# build-and-test.sh built (bzImage-co10-*). rc2 carries 41 Bluetooth commits
# (git log v6.6.159..c578c158a368 -- net/bluetooth drivers/bluetooth
# include/net/bluetooth), so this compares the whole subsystem's verdicts.
#
# Usage: all-testers.sh <out-dir> <kernel-tag>     (the directory must not exist)
#   kernel-tag: co10-6.6.160-rc2 or co10-6.6.159
# Each tester runs once (mgmt-tester is in build-and-test.sh); verdicts per test
# name are compared afterwards with compare-verdicts.py.
set -u
OUT=${1:?usage: all-testers.sh <out-dir> <kernel-tag>}
TAG=${2:?usage: all-testers.sh <out-dir> <kernel-tag>}
[[ -e "$OUT" ]] && { echo "refusing: $OUT exists"; exit 2; }
mkdir -p "$OUT"

REPO=/root/exp/qca9377-bt-hang
BLUEZ=$REPO/cache/bluez-bt9
IMG=$REPO/tmp/mesh-tester-ci/bzImage-$TAG
QEMU=$REPO/tmp/mesh-tester-ci/qemu-smp.sh
[[ -r "$IMG" ]] || { echo "no kernel image $IMG"; exit 2; }

exec > >(tee -a "$OUT/run.log") 2>&1
echo "start $(date -u '+%F %T') UTC  kernel $TAG  $(sha256sum "$IMG" | cut -d' ' -f1)"
for t in l2cap-tester iso-tester bnep-tester rfcomm-tester sco-tester ioctl-tester mesh-tester smp-tester userchan-tester 6lowpan-tester; do
	log="$OUT/$TAG.$t.log"
	echo "-- $t $(date -u '+%T')"
	( cd "$BLUEZ" && timeout 3600 tools/test-runner -q "$QEMU" -k "$IMG" -- "$BLUEZ/tools/$t" ) >"$log" 2>&1
	echo "   exit=$?  $(grep -a -E 'Total: ' "$log" | tail -n 1)"
	echo "   splat lines: $(grep -a -c -E 'BUG:|KASAN|WARNING:|possible circular|possible recursive|inconsistent lock|sleeping function' "$log")"
done
sha256sum "$OUT"/*.log > "$OUT/SHA256SUMS"
echo "done $(date -u '+%F %T') UTC"
