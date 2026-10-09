#!/bin/bash
# sha256-phase5.sh - phase 5 §G: the sha256 list of every raw log, build log,
# image, config, exported patch and helper of phase 5, relative to
# tmp/mesh-tester-ci/, written to logs/phase5/SHA256SUMS (which is not listed
# in itself). Verify later with: (cd tmp/mesh-tester-ci && sha256sum -c logs/phase5/SHA256SUMS)
set -euo pipefail
cd /root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
shopt -s nullglob
files=()
for f in logs/phase5/* series-v3/*.patch series-v3/*.txt series-v3/*/* \
	bzImage-v3* config-v3* \
	build.mk case-trace.sh pw-search.sh pw-patch.sh splat-check.sh \
	guest-kprobe-trace.sh run-trace.sh series-backport-check-local.sh \
	stable-dep-check.sh frag-*.config build-chain-*.sh gates-*.sh \
	export-*.sh rebuild-final-branch.sh sha256-phase5.sh \
	duration-overflow-note-v3.md; do
	[ "$f" = logs/phase5/SHA256SUMS ] && continue
	[ -f "$f" ] && files+=("$f")
done
sha256sum "${files[@]}" > logs/phase5/SHA256SUMS
wc -l logs/phase5/SHA256SUMS
sha256sum logs/phase5/SHA256SUMS
