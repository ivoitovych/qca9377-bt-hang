#!/bin/sh
# CO-36 L1: run the unit harness in the CI image, log to <logdir>/unit-run-<n>.log.
# usage: run-unit.sh [-s <pipewire tree>] [-f <backend-native.c>] [-o <logdir>] [-- test args (-v, IDs)]
#   -s  tree with build-v0-asan/ (headers, config.h); default: master
#   -f  a variant's backend-native.c, used in place of the tree's
# No devices, no network: the container gets the directories read-only.
set -eu

UNIT=$(dirname "$(readlink -f "$0")")
SRC=/root/exp/qca9377-bt-hang/cache/co36-pw-master
LOGDIR=/root/exp/qca9377-bt-hang/tmp/co36
IMAGE=co36-pw-ci:f44
VARIANT=

while [ $# -gt 0 ]; do
	case "$1" in
	-s) SRC=$(readlink -f "$2"); shift 2 ;;
	-f) VARIANT=$(readlink -f "$2"); shift 2 ;;
	-o) LOGDIR=$(readlink -f "$2"); shift 2 ;;
	--) shift; break ;;
	*) break ;;
	esac
done

mkdir -p "$LOGDIR"
n=1
while [ -e "$LOGDIR/unit-run-$n.log" ]; do
	n=$((n + 1))
done
LOG=$LOGDIR/unit-run-$n.log

set -- -v "$SRC:/src:ro" -v "$UNIT:/unit:ro" ${VARIANT:+-v "$VARIANT:/variant/backend-native.c:ro"} \
	-w /unit "$IMAGE" /bin/sh /unit/build-and-run.sh "$@"

{
	echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ) tree $SRC at $(git -C "$SRC" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)$(git -C "$SRC" diff --quiet -- spa/plugins/bluez5 2>/dev/null || echo ' (bluez5 modified)')${VARIANT:+, variant $VARIANT}"
	docker run --rm --network none "$@" 2>&1
} > "$LOG" 2>&1 || true

grep -E '^(T[0-9]|#)' "$LOG" || true
echo "log: $LOG"
