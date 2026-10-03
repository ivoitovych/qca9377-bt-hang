#!/bin/bash
# stable-tips-check.sh — the same-minute freshness check for a stable backport
# request: fetch stable, then compare each requested line's tip with the tip
# recorded in the cherry-pick/build exhibit. Unchanged → that exhibit is still
# the current proof; moved → rerun scripts/build-btusb-stable-matrix.sh for the
# moved line(s). The old backport-check.sh (patch --dry-run) is not the
# authority for this any more.
#
#   scripts/stable-tips-check.sh <exhibit.md> <stable-branch>…
#   e.g. scripts/stable-tips-check.sh evidence/exhibits/059-*.md stable/linux-7.2.y …
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EX="${1:?usage: stable-tips-check.sh <exhibit.md> <stable-branch>…}"; shift
(( $# )) || { echo "name the requested branches" >&2; exit 2; }
git -C "$HERE/cache/linux" fetch -q stable 2>/dev/null || { echo "fetch failed" >&2; exit 2; }
rc=0
for b in "$@"; do
	now=$(git -C "$HERE/cache/linux" rev-parse --short=12 "$b" 2>/dev/null || echo "?")
	rec=$(grep -oE "^$b +[0-9a-f]{12}" "$EX" | awk '{ print $2 }')
	if [[ -z "$rec" ]]; then printf '%-22s %s  NOT IN EXHIBIT\n' "$b" "$now"; rc=1
	elif [[ "$now" == "$rec" ]]; then printf '%-22s %s  unchanged\n' "$b" "$now"
	else printf '%-22s %s  MOVED (exhibit: %s) — rerun the matrix for it\n' "$b" "$now" "$rec"; rc=1; fi
done
exit $rc
