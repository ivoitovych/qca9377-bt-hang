#!/bin/bash
# gen-spec.sh <spec file to write> <kernel tags, comma separated> <first n> <last n> <label prefix>
# Writes a run-batch spec: for each n and each kernel, the six scenarios of the B2 acceptance
# matrix (dead, recover, close, dropcmd, wedge, cycles).
set -u
out=${1:?usage}
tags=${2:?usage}
a=${3:?usage}
b=${4:?usage}
p=${5:?usage}
{
	for n in $(seq "$a" "$b"); do
		for tag in ${tags//,/ }; do
			echo "$tag $p-dead-$n bt17 --fail-at 1"
			echo "$tag $p-recover-$n bt17 --fail-at 1 --recover"
			echo "$tag $p-close-$n close-recover --fail-at 1 --recover"
			echo "$tag $p-dropcmd-$n dropcmd"
			echo "$tag $p-wedge-$n dropcmd-wedge --drop-hci-event 0x0c24 --wedge-until-reset"
			echo "$tag $p-cycles-$n cycles --cycles 30"
		done
	done
} >"$out"
