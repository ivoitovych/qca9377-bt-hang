#!/bin/bash
# build-chain-kcsan.sh - phase 5 §E: KCSAN guest images (KASAN off), series and
# unpatched base, with CONFIG_AUDIT (see frag-kcsan-audit.config for why).
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

build v3-series-leakfix-kcsan scratch/with-upstream-leak-fix-on-a4023e09b21d "$F/frag-kcsan-audit.config"
build v3base-unpatched-kcsan 08e90633377f "$F/frag-kcsan-audit.config"
git -C "$G" checkout mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03
echo "all done $(date '+%F %T')"
