#!/bin/bash
# ci-log-search.sh — fetch the FULL log of a CI run (not only the failed step)
# into tmp/ and print the lines matching a pattern, with counts. For questions
# like "did any step print 'command not found'?" that devtools/ci --failed
# cannot answer because they hide inside a step that passed.
#
#   scripts/ci-log-search.sh <run-id|sha> <grep -E pattern>
set -uo pipefail
REPO=/root/exp/qca9377-bt-hang
ID="${1:?usage: ci-log-search.sh <run-id|sha> <pattern>}"; PAT="${2:?pattern}"
cd "$REPO" || exit 2
if [[ ! "$ID" =~ ^[0-9]{6,}$ ]]; then
    ID=$(gh run list --limit 30 --json databaseId,headSha --jq ".[] | select(.headSha | startswith(\"$ID\")) | .databaseId" | head -1)
    [[ -n "$ID" ]] || { echo "no run found for $1" >&2; exit 2; }
fi
mkdir -p tmp
LOG="tmp/ci-full-$ID.log"
[[ -s "$LOG" ]] || gh run view "$ID" --log > "$LOG" 2>&1 || { echo "could not fetch log for run $ID" >&2; exit 2; }
echo "run $ID — $(wc -l < "$LOG") lines; matches for /$PAT/: $(grep -cE "$PAT" "$LOG")"
grep -nE "$PAT" "$LOG" | sed -E $'s/^([0-9]+):[^\t]*\t([^\t]*)\t[0-9TZ:.-]+ ?/\\1 [\\2] /' | cut -c1-200 | head -40
