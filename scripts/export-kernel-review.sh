#!/bin/bash
# export-kernel-review.sh — the reviewer package for the held kernel patch, as
# plain files, taken from the held branch without checking it out: everything
# under patches/kernel/ (the patch, its README, the reviewer brief
# REVIEW-TASK.md, the reproducer) and the exhibits the README cites.
# Nothing is pushed anywhere; the operator hands the directory over privately.
# The brief itself lives on the held branch, not here: it describes the
# finding, and this public file must not (BRIEF §7).
#
#   scripts/export-kernel-review.sh            writes tmp/review-kernel-0001/
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BR="${BT_HELD_BRANCH:-kernel/mgmt-flush-status}"
OUT="$REPO/tmp/review-kernel-0001"
rm -rf "$OUT"; mkdir -p "$OUT"
mapfile -t FILES < <(git -C "$REPO" ls-tree -r --name-only "$BR" -- patches/kernel evidence/exhibits)
n=0
for f in "${FILES[@]}"; do
	case "$f" in
		patches/kernel/*|evidence/exhibits/044-*|evidence/exhibits/049-*|evidence/exhibits/050-*) ;;
		*) continue ;;
	esac
	mkdir -p "$OUT/$(dirname "$f")"
	git -C "$REPO" show "$BR:$f" > "$OUT/$f"
	n=$((n + 1))
done
(( n > 0 )) || { echo "nothing exported from $BR" >&2; exit 1; }
find "$OUT" -type f | sed "s|$OUT/||" | sort
echo "-> $OUT  ($n files; start with patches/kernel/REVIEW-TASK.md)"
