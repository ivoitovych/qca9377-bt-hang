#!/bin/sh
# L1 harness (homework/unit, test file unchanged) on one variant's
# backend-native.c, in co36-pw-ci:f44, no network, no devices, no cores.
# Usage: run-unit-variant.sh <v0|v2|v3> <run number>
# Output: logs/unit-<variant>-run<n>.log
set -eu

W=/root/exp/agent-work/co36-v2v3-20261101
SRC=/root/exp/agent-work/co36/pw
v=$1
n=$2
LOG=$W/logs/unit-$v-run$n.log
F=$W/variants/$v/backend-native.c

echo "$(date +%H:%M:%S) unit $v run$n start" >> "$W/progress.log"
{
	echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ) tree $SRC at $(git -C "$SRC" rev-parse HEAD), variant $v file $F"
	echo "# test file: $(sha256sum "$W/unit/test-backend-native.c")"
	docker run --rm --network none --ulimit core=0 \
		-v "$SRC:/src:ro" -v "$W/unit:/unit:ro" \
		-v "$F:/variant/backend-native.c:ro" \
		-w /unit co36-pw-ci:f44 /bin/sh /unit/build-and-run.sh 2>&1
} > "$LOG" 2>&1 || true
echo "$(date +%H:%M:%S) unit $v run$n end" >> "$W/progress.log"
grep -c -E '^T[0-9]' "$LOG" || true
echo "log: $LOG"
