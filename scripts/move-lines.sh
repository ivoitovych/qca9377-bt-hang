#!/bin/bash
# move-lines.sh — move an inclusive line range of one file, verbatim, to the end
# of another file under a heading, and delete it from the source. For retiring
# superseded hand-off blocks from BRIEF.md into HISTORY.md without retyping or
# altering a character of them (the dated record keeps what was written).
#
#   scripts/move-lines.sh <src> <from> <to> <dst> "<heading line>"
#
# Prints the moved line count and both files' new lengths. Refuses when the
# range is out of bounds. Nothing else is touched; review with git diff.
set -uo pipefail
SRC="${1:?usage: move-lines.sh <src> <from> <to> <dst> <heading>}"
FROM="${2:?from}"; TO="${3:?to}"; DST="${4:?dst}"; HEAD="${5:?heading}"
[[ -r "$SRC" && -w "$SRC" ]] || { echo "move-lines: cannot read/write $SRC" >&2; exit 2; }
[[ -w "$DST" ]] || { echo "move-lines: cannot write $DST" >&2; exit 2; }
total=$(wc -l < "$SRC")
(( FROM >= 1 && TO >= FROM && TO <= total )) || { echo "move-lines: range $FROM-$TO outside 1-$total" >&2; exit 2; }
TMP=$(mktemp) || exit 1
trap 'rm -f "$TMP"' EXIT
{ printf '\n%s\n\n' "$HEAD"; sed -n "${FROM},${TO}p" "$SRC"; } >> "$DST"
sed "${FROM},${TO}d" "$SRC" > "$TMP"
cat "$TMP" > "$SRC"
echo "moved $(( TO - FROM + 1 )) lines: $SRC now $(wc -l < "$SRC") lines, $DST now $(wc -l < "$DST") lines"
