#!/bin/bash
# run-rest.sh - research-sco: the remaining guest runs, one after another.
#   1. runs 2-3 of both sco-testers on base, co01, co02, both (run 1 logs exist, skipped)
#   2. 3 runs of the CO-01 l2cap cases only (-s "Close Before Complete"; a full l2cap-tester run
#      stalls in the SCI cases on this base, BT-15) under the name l2cap-cbcf-co01
#   3. SMP (4 CPUs): 3 runs of both sco-testers on both-smp and co01-smp
#   4. bluetooth-next tip: CO-02 alone and CO-02 + the CO-30 RFC, sco-tester-co02 and the
#      earlier experimental tester (sco-tester-exp, copied to bin/) with its retry cases
set -u
M=/root/exp/agent-work/research-sco/scripts/run-matrix.sh
$M 3 1 base,co01,co02,both sco-tester-co01,sco-tester-co02
$M 3 1 base,co01,co02,both l2cap-cbcf-co01 -s "Close Before Complete"
$M 3 4 both-smp,co01-smp sco-tester-co01,sco-tester-co02
$M 3 1 tipco02,tiprfc sco-tester-co02
$M 3 1 tipco02,tiprfc sco-tester-exp -s "Reconnect During Disconnect"
$M 1 1 tipco02,tiprfc sco-tester-exp -s "Exp "
echo "run-rest done $(date '+%T')"
