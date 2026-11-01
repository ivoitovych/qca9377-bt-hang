#!/bin/sh
# Runs 2 and 3 of the L1 harness on v0, v2, v3 (sequential).
set -u
S=/root/exp/agent-work/co36-v2v3-20261101/scripts
for n in 2 3; do
	for v in v0 v2 v3; do
		"$S/run-unit-variant.sh" "$v" "$n"
	done
done
echo "batch done"
