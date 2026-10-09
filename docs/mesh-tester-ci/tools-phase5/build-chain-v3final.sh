#!/bin/bash
# build-chain-v3final.sh - phase 5: the guest images of the final sequence,
# one after the other in cache/mesh-guest (one .config at a time).
#   v3final-leakfix        scratch/with-upstream-leak-fix-on-b78e2dd67680 (series + local cleanup), fault injection
#   v3final-leakfix-trace  the same commit, fault injection + kprobe events (branch evidence)
#   v3final                mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03 (series alone), fault injection
set -euo pipefail
G=/root/exp/qca9377-bt-hang/cache/mesh-guest
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5

echo "start $(date '+%F %T')"
git -C "$G" checkout scratch/with-upstream-leak-fix-on-b78e2dd67680
make -C "$G" -f "$MK" kernel-all KTAG=v3final-leakfix FRAG="$F/frag-fault.config" LOGDIR="$L"
echo "v3final-leakfix done $(date '+%F %T')"
make -C "$G" -f "$MK" kernel-all KTAG=v3final-leakfix-trace FRAG="$F/frag-fault-kprobe.config" LOGDIR="$L"
echo "v3final-leakfix-trace done $(date '+%F %T')"
git -C "$G" checkout mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03
make -C "$G" -f "$MK" kernel-all KTAG=v3final FRAG="$F/frag-fault.config" LOGDIR="$L"
echo "v3final done $(date '+%F %T')"
