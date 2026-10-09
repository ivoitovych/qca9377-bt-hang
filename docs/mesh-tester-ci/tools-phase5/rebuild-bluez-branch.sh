#!/bin/bash
# rebuild-bluez-branch.sh - phase 5: re-create the BlueZ branch with the
# revised message of the shared/mgmt patch (the mgmt-tester figure added).
# Code unchanged; the previous tip is kept on keep/mesh-tester-phase5-6640247e6.
set -euo pipefail
B=/root/exp/qca9377-bt-hang/cache/bluez-upstream
M=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-v3/msg-bluez-shared-mgmt.txt
OLD=6640247e6
git -C "$B" branch keep/mesh-tester-phase5-6640247e6 "$OLD"
git -C "$B" checkout --detach 8e1574ed6
git -C "$B" cherry-pick --no-commit 60888a265
git -C "$B" commit -F "$M"
git -C "$B" cherry-pick 05e973d72 6640247e6
NEW=$(git -C "$B" rev-parse --short=9 HEAD)
echo "tree diff old..new:"
git -C "$B" diff --stat "$OLD" "$NEW"
echo "(end of tree diff)"
git -C "$B" branch -f mesh-tester/phase5-lifecycle-tests-2026-10-03 "$NEW"
git -C "$B" checkout mesh-tester/phase5-lifecycle-tests-2026-10-03
git -C "$B" log --format='%h %s' -5
