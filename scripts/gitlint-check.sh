#!/bin/bash
# gitlint-check.sh — run gitlint on the commit message of each patch file with
# the BlueZ TREE's own .gitlint; message = everything above the first "---" with
# the mail headers stripped. This is NOT the file the BlueZ CI bot uses: the bot
# has its own gitlint file (title limit 80, Fixes:/Link:/URL exceptions), and
# scripts/ci-local.sh runs that one (default <action-ci>/gitlint). For the bot's
# verdict use ci-local.sh; this script answers "does the tree's own config pass".
#
#   scripts/gitlint-check.sh <bluez-tree> <patch>...
#
# gitlint is not packaged here; it is installed once into a virtualenv under
# cache/ (ignored), never system-wide. Prints gitlint's own output per patch
# and one summary line; exit 1 if any patch has a violation, 2 if gitlint
# cannot be set up.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:?usage: gitlint-check.sh <bluez-tree> <patch>...}"; shift
(( $# )) || { echo "no patches given" >&2; exit 2; }
[[ -f "$TREE/.gitlint" ]] || { echo "no .gitlint in $TREE" >&2; exit 2; }
VENV="$REPO/cache/gitlint-venv"
if [[ ! -x "$VENV/bin/gitlint" ]]; then
	python3 -m venv "$VENV" || exit 2
	"$VENV/bin/pip" install --quiet gitlint || exit 2
fi
"$VENV/bin/gitlint" --version
rc=0
for p in "$@"; do
	echo "── $(basename "$p")"
	# Subject: line becomes the title; body starts after the blank line that
	# ends the headers; the message ends at the separator.
	msg=$(awk '
		/^---$/ { exit }
		hdr && /^Subject: / { sub(/^Subject: /, ""); title = $0; next }
		hdr && /^$/ { hdr = 0; print title; print ""; next }
		hdr { next }
		{ print }
	' hdr=1 "$p")
	if out=$(printf '%s\n' "$msg" | "$VENV/bin/gitlint" -C "$TREE/.gitlint" 2>&1); then
		echo "   PASS  no violations"
	else
		printf '%s\n' "$out"
		echo "   FAIL  $(printf '%s\n' "$out" | grep -c ': [A-Z][0-9]* ') violation(s)"
		rc=1
	fi
done
exit $rc
