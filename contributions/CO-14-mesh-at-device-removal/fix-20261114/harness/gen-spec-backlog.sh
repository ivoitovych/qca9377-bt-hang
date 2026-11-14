#!/bin/bash
# gen-spec-backlog.sh <spec file> <kernel tags, comma separated> <label prefix>
# One line per boot: 10 boots per kernel, the same removal offsets (ms after the sends were queued) for every
# kernel; each boot removes 4 controllers (one set of offsets) and then 3 more without sends (see
# mesh-removal.py, --trailing).
set -u
out=${1:?usage}
tags=${2:?usage}
p=${3:?usage}
sets=(
	"50,200,450,900"
	"100,300,500,1100"
	"20,150,480,700"
	"250,495,505,1400"
	"80,400,510,800"
	"30,120,490,1000"
	"60,350,520,600"
	"150,450,500,1200"
	"40,250,515,950"
	"200,480,530,750"
)
{
	for i in "${!sets[@]}"; do
		n=$((i + 1))
		for tag in ${tags//,/ }; do
			echo "$tag $p-$n backlog --n 3 --cnt 20 --remove-after-ms ${sets[$i]} --iterations 4 --trailing 3"
		done
	done
} >"$out"
