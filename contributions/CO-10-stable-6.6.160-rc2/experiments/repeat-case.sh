#!/bin/bash
# repeat-case.sh - CO-10: run one tester case N times on each of the two CO-10
# kernels, to tell a real verdict difference from a flaky case.
#
# Usage: repeat-case.sh <out-dir> <tester> <word> [N]
#   e.g. repeat-case.sh tmp/co10-20261021-repeat-l2cap l2cap-tester limit 3
# <word> is passed to the tester as -s <word> (cases whose name contains it).
# It must be ONE word: test-runner hands the guest its arguments in one
# string and the guest splits it at spaces, so a multi-word filter is lost
# (found 2026-10-21: "-p L2CAP Ext-Flowctl Client - Defer limit" ran the whole
# tester). The directory must not exist. Prints one verdict line per run.
set -u
OUT=${1:?usage}; T=${2:?usage}; P=${3:?usage}; N=${4:-3}
[[ -e "$OUT" ]] && { echo "refusing: $OUT exists"; exit 2; }
mkdir -p "$OUT"
REPO=/root/exp/qca9377-bt-hang
BLUEZ=$REPO/cache/bluez-bt9
QEMU=$REPO/tmp/mesh-tester-ci/qemu-smp.sh
for tag in co10-6.6.159 co10-6.6.160-rc2; do
	for i in $(seq 1 "$N"); do
		log="$OUT/$tag.$T.$i.log"
		( cd "$BLUEZ" && timeout 600 tools/test-runner -q "$QEMU" -k "$REPO/tmp/mesh-tester-ci/bzImage-$tag" -- "$BLUEZ/tools/$T" -s "$P" ) >"$log" 2>&1
		echo "$tag run $i exit=$?"
		sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -a -E "$P.*(Passed|Failed|Timed out|Not Run) +[0-9.]+ seconds"
	done
done
sha256sum "$OUT"/*.log > "$OUT/SHA256SUMS"
