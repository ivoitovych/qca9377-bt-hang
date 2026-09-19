#!/bin/bash
# Proof for the devtools/ci cwd fix, run against the REAL gh from a directory
# that is not the checkout: before the fix this printed "no run found … not
# pushed, or Actions has not queued it yet" for a green sha; after it, the
# verdict. Read-only; one network call.
set -uo pipefail
REPO=/root/exp/qca9377-bt-hang
SHA=$(git -C "$REPO" rev-parse --short origin/main)
echo "from /root/exp (not a git repository), asking about origin/main $SHA:"
cd /root/exp && "$REPO/devtools/ci" "$SHA"; echo "rc=$?"
