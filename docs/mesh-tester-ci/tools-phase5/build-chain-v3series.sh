#!/bin/bash
# build-chain-v3series.sh - phase 5: the guest images of the recommended final
# sequence (mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03 =
# a4023e09b21d), one after the other in cache/mesh-guest.
#   v3-series-leakfix          scratch/with-upstream-leak-fix-on-a4023e09b21d, fault injection (KASAN, lockdep)
#   v3-series-leakfix-trace    the same commit, fault injection + kprobe events (branch evidence)
#   v3-series                  a4023e09b21d alone (no local cleanup), fault injection
#   v3-series-leakfix-kcsan    the scratch commit, KCSAN instead of KASAN (frag-kcsan.config)
#   v3base-unpatched-kcsan     08e90633377f, KCSAN instead of KASAN
set -euo pipefail
G=/root/exp/qca9377-bt-hang/cache/mesh-guest
F=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
MK=$F/build.mk
L=$F/logs/phase5

build() {
	echo "== $1 at $2 start $(date '+%F %T')"
	git -C "$G" checkout "$2"
	make -C "$G" -f "$MK" kernel-all KTAG="$1" FRAG="$3" LOGDIR="$L"
	echo "== $1 done $(date '+%F %T')"
}

build v3-series-leakfix scratch/with-upstream-leak-fix-on-a4023e09b21d "$F/frag-fault.config"
build v3-series-leakfix-trace scratch/with-upstream-leak-fix-on-a4023e09b21d "$F/frag-fault-kprobe.config"
build v3-series mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03 "$F/frag-fault.config"
build v3-series-leakfix-kcsan scratch/with-upstream-leak-fix-on-a4023e09b21d "$F/frag-kcsan.config"
build v3base-unpatched-kcsan 08e90633377f "$F/frag-kcsan.config"
git -C "$G" checkout mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03
echo "all done $(date '+%F %T')"
