#!/bin/bash
# ci-log-search.sh — fetch the FULL log of a CI run (not only the failed step)
# into tmp/ and print the lines matching a pattern, with counts. For questions
# like "did any step print 'command not found'?" that devtools/ci --failed
# cannot answer because they hide inside a step that passed.
#
#   scripts/ci-log-search.sh <run-id|sha> <grep -E pattern>
set -uo pipefail
# The checkout is wherever this script lives, not one machine's path: an external
# reviewer cloning elsewhere must be able to run it (deep-review follow-up).
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ID="${1:?usage: ci-log-search.sh <run-id|sha> <pattern>}"; PAT="${2:?pattern}"
cd "$REPO" || exit 2
if [[ ! "$ID" =~ ^[0-9]{6,}$ ]]; then
    ID=$(gh run list --limit 30 --json databaseId,headSha --jq ".[] | select(.headSha | startswith(\"$ID\")) | .databaseId" | head -1)
    [[ -n "$ID" ]] || { echo "no run found for $1" >&2; exit 2; }
fi
mkdir -p tmp
LOG="tmp/ci-full-$ID.log"
# Download to a temp file and move it into place only on success: a failed gh
# left its error text under the cache name, and the next run read that as the
# log (deep-review follow-up).
if [[ ! -s "$LOG" ]]; then
    T=$(mktemp "tmp/ci-full-$ID.XXXXXX")
    if gh run view "$ID" --log > "$T" 2>/dev/null; then mv "$T" "$LOG"
    else echo "could not fetch log for run $ID: $(gh run view "$ID" --log 2>&1 >/dev/null | tail -1)" >&2; rm -f "$T"; exit 2; fi
fi
echo "run $ID — $(wc -l < "$LOG") lines; matches for /$PAT/: $(grep -cE "$PAT" "$LOG")"
grep -nE "$PAT" "$LOG" | sed -E $'s/^([0-9]+):[^\t]*\t([^\t]*)\t[0-9TZ:.-]+ ?/\\1 [\\2] /' | cut -c1-200 | head -40
