#!/bin/bash
# run-all-7.sh : the measurement matrix of this work (one guest at a time, every guest has KASAN and lockdep)
W=/root/exp/agent-work/lane7-sco-20261114
R=$W/scripts/run-matrix.sh
# layout (a) tester: BlueZ patch 1 only (33 cases) on base and on kernel patches 1+2
$R b1 3 base,a12 b1 sco-tester
# full tester (35 cases + 4 incoming-link cases) on base, 1+2, 1+2+3
$R full 3 base,a12,a123 inc2 sco-tester
# incoming-link cases with the worker parkable: base, 1+2 (lane2's parkB), 1+2+3
$R park 3 parkbase,parkB,parkC inc2 sco-tester
# the other BlueZ testers on 1+2 alone and 1+2+3 (lockdep guests, 1 run each)
$R full 1 annot inc2 sco-tester
$R mgmt 1 a12,a123 inc2 mgmt-tester
$R iso 1 a12,a123 inc2 iso-tester
echo "run-all-7 done"
