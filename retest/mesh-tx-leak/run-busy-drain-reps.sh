#!/bin/sh
# Repeat the busy-drain scenario (both advertising types).
# Usage: run-busy-drain-reps.sh <build-name> <reps> [jobs]
# Environment: WORK, BLUEZ as for run-matrix.sh
# Exits non-zero if any run does.
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
		for adv in legacy ext; do
			echo "busy-drain-$adv-r$rep $REPRO busy-drain $adv"
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
