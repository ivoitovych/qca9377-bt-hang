#!/bin/bash
# series-backport-check.sh — does a patch SERIES (ordered patch files) apply to
# each stable branch? Unlike backport-check.sh, which takes one mainline commit,
# this takes patch files and applies them cumulatively, so a later patch may
# rely on context an earlier one added. Read-only: the files each patch touches
# are copied from the branch into tmp/series-backport-check/<branch>/ and the
# patches are applied there with patch(1); no checkout is modified.
#
#   scripts/series-backport-check.sh <branch>[,<branch>…] <patch>…
#   e.g. scripts/series-backport-check.sh stable/linux-6.12.y,stable/linux-6.6.y series/0001-*.patch series/0002-*.patch
#
# Per branch: APPLIES (with offset/fuzz if any) or FAILS at patch N. Fetch
# first: git -C cache/linux fetch stable.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$HERE/cache/linux"
BR="${1:?usage: series-backport-check.sh <branch>[,<branch>…] <patch>…}"; shift
(( $# )) || { echo "no patch files given" >&2; exit 2; }
IFS=, read -r -a BRANCHES <<<"$BR"
OUT="$HERE/tmp/series-backport-check"
rm -rf "$OUT"; mkdir -p "$OUT"
# files touched by any patch in the series
mapfile -t FILES < <(grep -h '^+++ b/' "$@" | sed 's#^+++ b/##' | sort -u)
echo "patches: $*"
echo "files:   ${FILES[*]}"
rc=0
for b in "${BRANCHES[@]}"; do
	tip=$(git -C "$REPO" log -1 --format='%h %s' "$b" 2>/dev/null) || { printf '%-22s ? no such branch\n' "$b"; rc=1; continue; }
	d="$OUT/${b//\//_}"; mkdir -p "$d"
	for f in "${FILES[@]}"; do
		mkdir -p "$d/$(dirname "$f")"
		git -C "$REPO" show "$b:$f" > "$d/$f" 2>/dev/null || : > "$d/$f"
	done
	notes=""; failed=""
	n=0
	for p in "$@"; do
		n=$((n+1))
		if res=$(patch -p1 -N -d "$d" < "$p" 2>&1); then
			o=$(grep -oE 'offset [-0-9]+ lines?|fuzz [0-9]+' <<<"$res" | tr '\n' ' ')
			[[ -n "$o" ]] && notes+="[$n: $o] "
		else
			failed="FAILS at patch $n: $(grep -m1 -E 'FAILED|malformed|Reversed' <<<"$res")"
			break
		fi
	done
	if [[ -n "$failed" ]]; then
		printf '%-22s %s   [tip %s]\n' "$b" "$failed" "${tip%% *}"; rc=1
	else
		printf '%-22s APPLIES  %s  [tip %s]\n' "$b" "$notes" "${tip%% *}"
	fi
done
exit "$rc"
