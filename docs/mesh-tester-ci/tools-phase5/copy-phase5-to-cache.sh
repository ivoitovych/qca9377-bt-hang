#!/bin/bash
# copy-phase5-to-cache.sh - phase 5 §G: keep the raw logs, the exported series
# and the results under cache/mesh-tester-ci-phase5/ (outside every git
# worktree, nothing committed), then verify source and copy against SHA256SUMS.
set -euo pipefail
S=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci
D=/root/exp/qca9377-bt-hang/cache/mesh-tester-ci-phase5
mkdir -p "$D/logs" "$D/series-v3" "$D/tools"
cp -a "$S/logs/phase5" "$D/logs/"
cp -a "$S/series-v3/." "$D/series-v3/"
cp -a "$S/phase5-results.md" "$S/duration-overflow-note-v3.md" "$D/"
cp -a "$S"/*.sh "$S"/build.mk "$S"/frag-*.config "$D/tools/"
cd "$S"
sha256sum -c --quiet logs/phase5/SHA256SUMS && echo "source: all SHA256SUMS entries OK"
cd "$D"
grep -E '  (logs/phase5|series-v3)/' "$S/logs/phase5/SHA256SUMS" | sha256sum -c --quiet - && echo "copy: logs/phase5 and series-v3 entries OK"
du -sh "$D"
