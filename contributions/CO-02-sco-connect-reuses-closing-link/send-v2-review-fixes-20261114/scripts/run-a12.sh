#!/bin/bash
# run-a12.sh : the 1+2 part of the matrix, run while a123 is still building (run-matrix.sh skips logs that exist)
W=/root/exp/agent-work/lane7-sco-20261114
R=$W/scripts/run-matrix.sh
$R b1 3 a12 b1 sco-tester
$R full 3 a12 inc2 sco-tester
$R mgmt 1 a12 inc2 mgmt-tester
$R iso 1 a12 inc2 iso-tester
echo "run-a12 done"
