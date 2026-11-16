#!/bin/bash
# Proof for the devtools/ci cwd fix, run against the REAL gh from a directory
# that is not the checkout: before the fix this printed "no run found … not
# pushed, or Actions has not queued it yet" for a green sha; after it, the
# verdict. Read-only; one network call.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SHA=$(git -C "$REPO" rev-parse --short origin/main)
ELSEWHERE=$(mktemp -d)   # any directory that is not a git repository
echo "from $ELSEWHERE (not a git repository), asking about origin/main $SHA:"
OUT=$(cd "$ELSEWHERE" && "$REPO/devtools/ci" "$SHA" 2>&1); rc=$?
printf '%s\n' "$OUT"; echo "rc=$rc"; rmdir "$ELSEWHERE"
# The proof holds when devtools/ci found the run: it must answer with a verdict,
# not with "no run found" (the pre-fix answer from outside the checkout), and
# must say something at all. Exit 1 otherwise.
if [[ -z "$OUT" || "$OUT" == *"no run found"* ]]; then echo "PROOF FAILED: no verdict from outside the checkout" >&2; exit 1; fi
