#!/bin/sh
# Clone the prepared CO-03 BlueZ tree (src/bluez) into the review area and
# make two branches on the unmodified import, by cherry-picking the commits
# already prepared on co03/u12-backport (author, date and message kept):
#   rev/cand3 = noble-5.72-0ubuntu5.8 + helper (3d9900eb754d part)
#               + a14d59725ef3 + 664a5d3785a1
#   rev/cand2 = noble-5.72-0ubuntu5.8 + helper + a14d59725ef3 (no 664a5d3785a1)
# and one detached worktree per branch under build/ for the sanitizer builds.
set -eu
R=/root/exp/agent-work/co03/review-20261101
SRC=/root/exp/agent-work/co03/src/bluez
B=$R/src/bluez
[ -e "$B" ] && { echo "exists: $B" >&2; exit 1; }
mkdir -p "$R/src" "$R/build"
git clone -q --no-checkout "$SRC" "$B"
git -C "$B" checkout -q -b rev/cand3 origin/noble-5.72-0ubuntu5.8
# the three upstream changes, as prepared (helper, fix, companion)
HELPER=$(git -C "$SRC" log --format=%H --grep='backported from commit 3d9900eb754d' co03/u12-backport)
FIX=$(git -C "$SRC" log --format=%H --grep='backported from commit a14d59725ef3' co03/u12-backport)
COMP=$(git -C "$SRC" log --format=%H --grep='backported from commit 664a5d3785a1' co03/u12-backport)
echo "helper $HELPER"; echo "fix $FIX"; echo "companion $COMP"
git -C "$B" -c user.name='Iaroslav Voitovych' -c user.email='yaroslav.voytovych@gmail.com' \
    cherry-pick "$HELPER" "$FIX" "$COMP"
git -C "$B" branch rev/cand2 rev/cand3~1
git -C "$B" log --format='%h %an | %s' -n 4 rev/cand3
git -C "$B" log --format='%h %an | %s' -n 3 rev/cand2
# does the cherry-picked code equal the prepared commits' code?
for c in "$HELPER" "$FIX" "$COMP"; do
    printf '%s patch-id prepared: ' "$c"
    git -C "$SRC" show "$c" | git patch-id --stable
done
for c in rev/cand3~2 rev/cand3~1 rev/cand3; do
    printf '%s patch-id here: ' "$c"
    git -C "$B" show "$c" | git patch-id --stable
done
echo "files cand3 vs base:"
git -C "$B" diff --stat origin/noble-5.72-0ubuntu5.8 rev/cand3
echo "cand3 vs prepared co03/u12-backport (expect only the BT-7 lines):"
git -C "$B" diff --stat rev/cand3 origin/co03/u12-backport
git -C "$B" worktree add -q --detach "$R/build/cand3" rev/cand3
git -C "$B" worktree add -q --detach "$R/build/cand2" rev/cand2
git -C "$B" worktree list
