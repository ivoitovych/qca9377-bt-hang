#!/bin/bash
# rebuild-final-branch.sh - phase 5: re-create the final sequence with the
# revised message of 1/5 (the 71af682ba469 stable prerequisite line dropped:
# that commit is in all five stable lines since 2026-10-03). Code unchanged.
# The previous tip is kept on keep/phase5-v3-final-a4023e09b21d.
set -euo pipefail
G=/root/exp/qca9377-bt-hang/cache/mesh-guest
M=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-v3/msg-0001.txt
OLD=a4023e09b21d
git -C "$G" branch keep/phase5-v3-final-a4023e09b21d "$OLD"
git -C "$G" checkout --detach 08e90633377f
git -C "$G" cherry-pick --no-commit f40c7a65bcb2
git -C "$G" commit -F "$M"
git -C "$G" cherry-pick c0b18e7ca30f 7cdb27a87fac 319c4bdbf89d a4023e09b21d
NEW=$(git -C "$G" rev-parse --short=12 HEAD)
echo "tree diff old..new:"
git -C "$G" diff --stat "$OLD" "$NEW"
echo "(end of tree diff)"
git -C "$G" branch -f mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03 "$NEW"
git -C "$G" checkout mesh/phase5-series-v3-final-on-bluetooth-master-2026-10-03
git -C "$G" log --format='%h %s' -6
