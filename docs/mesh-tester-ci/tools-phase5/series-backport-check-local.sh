#!/bin/bash
# series-backport-check-local.sh - a copy of scripts/series-backport-check.sh
# (same logic, line for line) whose scratch directory is under
# tmp/mesh-tester-ci/ instead of tmp/, because phase 5 may write only under
# cache/ and tmp/mesh-tester-ci/. REPO is the same cache/linux.
#
#   tmp/mesh-tester-ci/series-backport-check-local.sh <branch>[,<branch>…] <patch>…
set -uo pipefail
REPO=/root/exp/qca9377-bt-hang/cache/linux
BR="${1:?usage: series-backport-check-local.sh <branch>[,<branch>…] <patch>…}"; shift
(( $# )) || { echo "no patch files given" >&2; exit 2; }
IFS=, read -r -a BRANCHES <<<"$BR"
OUT=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-backport-check
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
