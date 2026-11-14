#!/bin/bash
# run-base.sh : the base-kernel part of the matrix (lane2's img/bzImage-base = bluetooth-next da3cc02587c6), run while the
# patched kernels are still building; run-matrix.sh skips logs that exist
W=/root/exp/agent-work/lane7-sco-20261114
R=$W/scripts/run-matrix.sh
$R b1 3 base b1 sco-tester
$R full 3 base inc2 sco-tester
echo "run-base done"
