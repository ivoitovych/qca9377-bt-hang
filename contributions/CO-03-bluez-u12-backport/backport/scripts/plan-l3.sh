#!/bin/sh
# The plan's L3 runs for one build: PipeWire's own VM tests (one session
# each), CO-03's L3 tests once, T310 ten times.
# Usage: plan-l3.sh <variant> <tag>     e.g. plan-l3.sh base v0
set -u
v=$1
tag=$2
s=/root/exp/agent-work/co03/scripts
r=/root/exp/agent-work/co03/runs
if [ "${3:-}" != noown ]; then
    echo "== L3 PipeWire's own tests $(date -Is)"
    $s/run-l3-pw-own.sh "$v" "$tag-l3pw"
fi
echo "== L3 CO-03 tests $(date -Is)"
$s/run-l3.sh "$v" "$tag-l3" -k "test_co03_pw" > "$r/$tag-l3.stdout.log" 2>&1
tail -1 "$r/$tag-l3.stdout.log"
echo "== L3 T310 x10 $(date -Is)"
CO03_REPS=10 $s/run-l3.sh "$v" "$tag-l3rates" -k "test_co03_pw and t310" \
    > "$r/$tag-l3rates.stdout.log" 2>&1
tail -1 "$r/$tag-l3rates.stdout.log"
echo "== done $(date -Is)"
