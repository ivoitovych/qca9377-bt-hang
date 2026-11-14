#!/bin/bash
# build-2.sh : kernels for layout (a)/(b): a12 = patches 1+2, a123 = patches 1+2+3 (branch l7-ab)
W=/root/exp/agent-work/lane7-sco-20261114
$W/scripts/build-kernel.sh a12 l7-ab~1 || exit 1
$W/scripts/build-kernel.sh a123 l7-ab || exit 1
echo "build-2 done"
