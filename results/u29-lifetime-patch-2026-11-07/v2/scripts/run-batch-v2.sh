#!/bin/sh
# Round 2: for the given arms, master base and patched, repetitions 0..2.
# One chain per arm/build (its three repetitions one after the other), all
# chains in parallel. Existing run directories are skipped.
# Usage: run-batch-v2.sh <arm>...
top=/root/exp/agent-work/u29-t3-lifetime-patch
chain() {
    for n in 0 1 2; do
        "$top/scripts-v2/run-arm-v2.sh" master "$1" "$2" "$n" || echo "FAILED master $1 $2 $n"
    done
}
for arm in "$@"; do
    for build in base patched; do
        chain "$build" "$arm" &
    done
done
wait
echo "batch done: $*"
