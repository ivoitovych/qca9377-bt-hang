#!/bin/sh
# Repeat the kmemleak scenarios to measure how often each scan method
# reports the leak.
# Usage: run-kmemleak-reps.sh <build-name> <reps> [jobs]
# Methods: inproc-plain  - scans from the still-running reproducer
#          inproc-shrink - same, slab caches shrunk before each scan
#          after-exit    - plain scans from a shell after it has exited
# Environment: WORK, BLUEZ as for run-matrix.sh
set -u
NAME=$1; REPS=$2; JOBS=${3:-3}
WORK=${WORK:-/home/user/work}
export BLUEZ=${BLUEZ:-$WORK/bluez}
HERE=$(cd "$(dirname "$0")" && pwd)
IMG=$WORK/build-$NAME/arch/x86/boot/bzImage
LOGS=$HERE/logs/reps-$NAME
REPRO=$BLUEZ/tools/mesh-leak-check
mkdir -p "$LOGS"

list() {
	for rep in $(seq 1 "$REPS"); do
		for sc in enetdown enomem enodev; do
			echo "$sc-inproc-plain-r$rep $REPRO kmemleak-$sc legacy plain"
			echo "$sc-inproc-shrink-r$rep $REPRO kmemleak-$sc legacy shrink"
			echo "$sc-after-exit-r$rep $HERE/kmemleak-after-exit.sh $REPRO $sc legacy"
		done
	done
}

if list | xargs -P "$JOBS" -L 1 sh -c \
	'tag=$1; shift; "'"$HERE"'/run-vm.sh" "'"$IMG"'" 1 "'"$LOGS"'/$tag.log" "$@"' sh
then
	echo "all runs exited 0"
else
	echo "some runs exited non-zero: see rc=/cmd=/splat= above"
	exit 1
fi
