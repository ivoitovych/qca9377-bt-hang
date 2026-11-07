#!/bin/sh
# The whole matrix for one tree: arms A-E,G-J, build base and patched,
# repetitions 0..2. Up to 6 containers run at once (one chain per
# arm/build, its three repetitions one after the other). Existing run
# directories are skipped, never overwritten.
# Usage: run-all.sh <master|5.72> [arms...]
top=/root/exp/agent-work/u29-t3-lifetime-patch
tree=$1
shift
arms=${*:-A B C D E G H I J}
chain() {
    for n in 0 1 2; do
        "$top/scripts/run-arm.sh" "$tree" "$1" "$2" "$n" || echo "FAILED $tree $1 $2 $n"
    done
}
for arm in $arms; do
    for build in base patched; do
        chain "$build" "$arm" &
    done
    # 2 chains per arm; wait after every third arm to cap concurrency (~6)
    case "$arm" in C|G) wait ;; esac
done
wait
echo "all chains done for $tree"
