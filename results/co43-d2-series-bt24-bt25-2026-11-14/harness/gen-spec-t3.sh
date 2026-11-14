#!/bin/bash
# gen-spec-t3.sh <spec file> <kernel tag>: the BT-24 / BT-25 runs for one kernel
out=${1:?usage}
t=${2:?usage}
{
	echo "$t k-healthy-1 kml --mode healthy --expect-no-leak"
	for n in 1 2 3; do
		echo "$t k-inject1-$n kml --mode healthy --inject 1 --expect-no-leak"
	done
	for n in 1 2 3; do
		echo "$t k-inject2-$n kml --mode healthy --inject 2 --expect-no-leak"
	done
	for n in 1 2 3; do
		echo "$t k-dead-$n kml --mode dead --fail-at 1 --expect-no-leak"
	done
	for n in 1 2 3; do
		echo "$t k-deadoff-$n kml --mode dead-off --fail-at 1 --expect-no-leak"
	done
	for n in 1 2 3; do
		echo "$t k-bt24-$n bt24 --delay 2500"
	done
} >"$out"
