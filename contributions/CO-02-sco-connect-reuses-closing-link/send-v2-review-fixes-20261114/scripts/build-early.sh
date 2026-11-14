#!/bin/bash
# build-early.sh : debug kernels whose worker parks BEFORE it reads the holders (w2c_park_ms, debug only, never posted):
#   eBase = bluetooth-next + early park ; e12 = patches 1+2 + early park ; e123 = patches 1+2+3 + early park
W=/root/exp/agent-work/lane7-sco-20261114
T=$W/linux
git -C "$T" checkout -q -B l7-ebase da3cc02587c629420603df4395179ec82955c941 || exit 1
git -C "$T" apply "$W/park-early.diff" || exit 1
git -C "$T" commit -q -a -m "early park (debug only)" || exit 1
git -C "$T" checkout -q -B l7-e12 l7-ab~1 || exit 1
git -C "$T" apply "$W/park-early.diff" || exit 1
git -C "$T" commit -q -a -m "early park (debug only)" || exit 1
git -C "$T" checkout -q -B l7-e123 l7-ab || exit 1
git -C "$T" apply "$W/park-early.diff" || exit 1
git -C "$T" commit -q -a -m "early park (debug only)" || exit 1
$W/scripts/build-kernel.sh ebase l7-ebase || exit 1
$W/scripts/build-kernel.sh e12 l7-e12 || exit 1
$W/scripts/build-kernel.sh e123 l7-e123 || exit 1
git -C "$T" checkout -q l7-ab
echo "early built"
