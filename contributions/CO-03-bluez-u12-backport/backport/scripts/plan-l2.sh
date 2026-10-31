#!/bin/sh
# The plan's L1 harness and L2 runs for one build.
# Usage: plan-l2.sh <variant> <tag>     e.g. plan-l2.sh base v0
set -u
v=$1
tag=$2
s=/root/exp/agent-work/co03/scripts
r=/root/exp/agent-work/co03/runs
echo "== L1 harness $(date -Is)"
$s/run-l1.sh "$v"
echo "== L2 all tests, 1 run each $(date -Is)"
$s/run-l2.sh "$v" "$tag-l2" > "$r/$tag-l2.stdout.log" 2>&1
tail -1 "$r/$tag-l2.stdout.log"
echo "== L2 trigger tests, 10 runs each $(date -Is)"
CO03_REPS=10 $s/run-l2.sh "$v" "$tag-l2rates" \
    -k "t201 or t202 or t203 or t204 or t205 or t206 or t207" \
    > "$r/$tag-l2rates.stdout.log" 2>&1
tail -1 "$r/$tag-l2rates.stdout.log"
echo "== done $(date -Is)"
