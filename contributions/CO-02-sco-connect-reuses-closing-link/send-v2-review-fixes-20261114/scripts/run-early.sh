#!/bin/bash
# run-early.sh : incoming-link cases (tester inc3) with the worker parked before it reads the holders (ebase, e12, e123)
# and after it has seen no holder (parkbase, parkB = lane2's 1+2, parkC), 3 runs each. Waits for run-all-7.sh first.
W=/root/exp/agent-work/lane7-sco-20261114
R=$W/scripts/run-matrix.sh
$R early 3 ebase,e12,e123 inc3 sco-tester
$R late 3 parkbase,parkB,parkC inc3 sco-tester
echo "run-early done"
