#!/bin/bash
# gen-spec-lockdep.sh <spec file> <kernel tags, comma separated> <label prefix>
# The lockdep hunt: 10 boots per kernel, 12 controllers each, one Mesh Send (Count 20: the transmission ends
# about 500 ms after it starts), the controller removed at offsets around that end, boot j at
# 470+j, 475+j, ... 525+j ms (so the offsets of the ten boots together cover 470 to 534 ms in 1 ms steps).
# No kmemleak scans (--no-kml). No debug delays.
set -u
out=${1:?usage}
tags=${2:?usage}
p=${3:?usage}
{
	for j in 0 1 2 3 4 5 6 7 8 9; do
		list=""
		for k in 0 1 2 3 4 5 6 7 8 9 10 11; do
			list="$list,$((470 + j + 5 * k))"
		done
		list=${list#,}
		for tag in ${tags//,/ }; do
			echo "$tag $p-$((j + 1)) backlog --n 1 --cnt 20 --remove-after-ms $list --iterations 12 --no-kml"
		done
	done
} >"$out"
