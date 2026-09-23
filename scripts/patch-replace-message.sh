#!/bin/bash
# patch-replace-message.sh — replace the header+message part of a format-patch
# file (everything above the first line that is exactly "---") with the text of
# a message file, keeping the diffstat and the diff byte for byte. Refuses if the
# diff part would change or if the message file itself contains a "---" line.
#
#   scripts/patch-replace-message.sh <patch> <message-file>     edits <patch> in place
set -uo pipefail
P="${1:?usage: patch-replace-message.sh <patch> <message-file>}"
M="${2:?usage: patch-replace-message.sh <patch> <message-file>}"
[[ -r "$P" && -r "$M" ]] || { echo "cannot read $P or $M" >&2; exit 2; }
grep -qx -- '---' "$M" && { echo "message file contains a --- line" >&2; exit 2; }
tmp=$(mktemp) || exit 2
cat "$M" > "$tmp"
awk 'f {print} /^---$/ && !f {f=1; print}' "$P" >> "$tmp"
if ! diff <(awk 'f{print} /^---$/{f=1}' "$P") <(awk 'f{print} /^---$/{f=1}' "$tmp") >/dev/null; then
	echo "diff part would change — refusing" >&2; rm -f "$tmp"; exit 1
fi
mv "$tmp" "$P"
echo "message replaced; diff unchanged: $P"
