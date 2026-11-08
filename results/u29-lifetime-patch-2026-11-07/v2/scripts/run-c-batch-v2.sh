#!/bin/sh
# Task C: base and patched, repetitions 0..2, one chain per build.
# Usage: run-c-batch-v2.sh <tag> <target>...    (targets as for run-c-v2.sh)
top=/root/exp/agent-work/u29-t3-lifetime-patch
tag=$1
shift
chain() {
    b=$1
    shift
    for n in 0 1 2; do
        "$top/scripts-v2/run-c-v2.sh" "$b" "$tag" "$n" "$@" || echo "FAILED C $tag $b $n"
    done
}
for build in base patched; do
    chain "$build" "$@" &
done
wait
echo "C batch done: $tag"
