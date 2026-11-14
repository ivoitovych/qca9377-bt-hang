#!/bin/bash
# gen-spec-hung.sh <spec file> <kernel tags, comma separated> <label prefix>
# A controller that stops answering and is then removed (scenario hung): one Mesh Send (Count 20), btvirt
# stopped after D ms with a Set Local Name pending, the transmission ends meanwhile, btvirt killed 300 ms later.
# 10 boots per kernel, 6 controllers each, D from 250 to 480 ms. No kmemleak scans. No debug delays.
set -u
out=${1:?usage}
tags=${2:?usage}
p=${3:?usage}
{
	for j in 1 2 3 4 5 6 7 8 9 10; do
		for tag in ${tags//,/ }; do
			echo "$tag $p-$j hung --n 1 --cnt 20 --remove-after-ms 250,300,350,400,450,480 --iterations 6 --no-kml"
		done
	done
} >"$out"
