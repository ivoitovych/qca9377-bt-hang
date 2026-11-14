#!/bin/bash
# build-park.sh : debug kernels with the w2c_park_ms parameter (debug only, never posted):
#   parkbase = bluetooth-next da3cc02587c6 + park ; parkC = patches 1+2+3 + park (parkB of lane2 = 1+2 + park)
W=/root/exp/agent-work/lane7-sco-20261114
T=$W/linux
git -C "$T" checkout -q -B l7-parkbase da3cc02587c629420603df4395179ec82955c941 || exit 1
git -C "$T" apply "$W/park.diff" || exit 1
git -C "$T" commit -q -a -m "park (debug only)" || exit 1
git -C "$T" checkout -q -B l7-parkC l7-ab || exit 1
git -C "$T" apply "$W/park.diff" || exit 1
git -C "$T" commit -q -a -m "park (debug only)" || exit 1
$W/scripts/build-kernel.sh parkbase l7-parkbase || exit 1
$W/scripts/build-kernel.sh parkC l7-parkC || exit 1
git -C "$T" checkout -q -B l7-annot l7-ab || exit 1
git -C "$T" apply "$W/proposal/abort-reason-readonce.diff" || exit 1
git -C "$T" commit -q -a -m "hci_conn: READ_ONCE the abort_reason check in hci_abort_conn (proposal)" || exit 1
$W/scripts/build-kernel.sh annot l7-annot || exit 1
git -C "$T" checkout -q l7-ab
echo "park built"
