#!/bin/bash
# prove-held-branch-guard.sh — standalone proof of the two suite assertions on repo-save's held-branch
# guard (kernel/* → private remote only), for when the suite cannot run (trial open).
set -uo pipefail
cd /root/exp/qca9377-bt-hang || exit 2
SCRATCH=$(mktemp -d)
pass=0; fail=0
ok()  { echo "  ✓ $*"; pass=$((pass+1)); }
bad() { echo "  ✗ $*"; fail=$((fail+1)); }
scratch_repo() { git -C "$1" init -q 2>/dev/null; git -C "$1" config user.email test@example.com; git -C "$1" config user.name test; }
mkdir -p "$SCRATCH/held"; scratch_repo "$SCRATCH/held"
git init -q --bare "$SCRATCH/held-origin.git"; git init -q --bare "$SCRATCH/held-private.git"
git -C "$SCRATCH/held" remote add origin "$SCRATCH/held-origin.git"
git -C "$SCRATCH/held" remote add private "$SCRATCH/held-private.git"
git -C "$SCRATCH/held" checkout -q -b kernel/held-test
printf 'held\n' > "$SCRATCH/held/held.txt"
HELD=$(devtools/repo-save "$SCRATCH/held" "held branch commit" 2>&1); heldrc=$?
hp=$(git --git-dir="$SCRATCH/held-private.git" rev-parse --verify --quiet refs/heads/kernel/held-test || echo none)
ho=$(git --git-dir="$SCRATCH/held-origin.git" rev-parse --verify --quiet refs/heads/kernel/held-test || echo none)
(( heldrc == 0 )) && [[ "$hp" != none && "$ho" == none && "$HELD" == *"never to origin"* ]] \
    && ok "repo-save pushes a kernel/* branch to 'private' and not to origin" \
    || { bad "held-branch push: rc=$heldrc private=$hp origin=$ho"; echo "$HELD" | tail -8; }
git -C "$SCRATCH/held" remote remove private
printf 'held 2\n' >> "$SCRATCH/held/held.txt"
HELD2=$(devtools/repo-save "$SCRATCH/held" "held branch, no private remote" 2>&1); held2rc=$?
ho2=$(git --git-dir="$SCRATCH/held-origin.git" rev-parse --verify --quiet refs/heads/kernel/held-test || echo none)
(( held2rc != 0 )) && [[ "$ho2" == none && "$HELD2" == *"no 'private' remote"* ]] \
    && ok "without a 'private' remote a kernel/* branch is refused, not pushed to origin" \
    || { bad "held branch without private remote: rc=$held2rc origin=$ho2"; echo "$HELD2" | tail -5; }
rm -rf "$SCRATCH"
echo "pass=$pass fail=$fail"; (( fail == 0 ))
