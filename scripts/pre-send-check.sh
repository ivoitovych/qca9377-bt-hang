#!/bin/bash
# pre-send-check.sh — the check that was missing on 2026-09-21: before mailing a
# patch, fetch the upstream tree and look at TODAY'S master, not the checkout
# from a month ago. Both BlueZ v2 mails went out 6.5 h after the maintainer had
# applied v1 — visible in one `git fetch`. Read-only on the checkout.
#
#   scripts/pre-send-check.sh <tree> <mail-or-patch>...
#
# For each file: (1) is a commit with the same subject already on
# origin/master? (2) does the patch apply to origin/master after the files
# before it? The files are applied in the order given, as a series, to a
# scratch index (`git apply --cached`), so a patch that depends on an earlier
# one is checked on top of it. A same-subject commit is reported as ALREADY
# APPLIED and the file fails the check even if the diff would still apply (a
# pure insertion applies twice). A folded Subject: header is unfolded.
#
# This is an applicability check only: it does not build, test or lint.
set -uo pipefail
TREE="${1:?usage: pre-send-check.sh <tree> <patch>...}"; shift
(( $# )) || { echo "no patches given" >&2; exit 2; }
git -C "$TREE" fetch --quiet origin || { echo "fetch failed — do not send on a stale tree" >&2; exit 2; }
echo "origin/master: $(git -C "$TREE" log -1 --format='%h %cs %s' origin/master)"
rc=0
# one scratch index for the whole series; the working tree is never touched
idx=$(mktemp) || exit 2
trap 'rm -f "$idx" "$idx.err"' EXIT
GIT_INDEX_FILE="$idx" git -C "$TREE" read-tree origin/master || exit 2
series_ok=1
for p in "$@"; do
	subj=$(awk '
		/^Subject: / { s = substr($0, 10); folded = 1; next }
		folded && /^[ \t]/ { sub(/^[ \t]+/, " "); s = s $0; next }
		folded { print s; exit }' "$p" | sed 's/^\(\[[^]]*\] \)*//')
	echo "── $(basename "$p")"
	echo "   subject: $subj"
	hit=$(git -C "$TREE" log --format='%h %cd %cn' --date=short -F --grep="$subj" origin/master | head -3)
	if [[ -n "$hit" ]]; then
		echo "   ALREADY APPLIED on origin/master:"
		sed 's/^/     /' <<<"$hit"
		rc=1
	fi
	if (( ! series_ok )); then
		echo "   applies to origin/master: not checked (an earlier patch did not apply)"
	elif GIT_INDEX_FILE="$idx" git -C "$TREE" apply --cached "$p" 2>"$idx.err"; then
		echo "   applies to origin/master (after the patches before it): yes"
	else
		echo "   applies to origin/master (after the patches before it): NO — $(head -1 "$idx.err")"
		series_ok=0
		rc=1
	fi
done
(( rc == 0 )) && echo "OK to send" || echo "DO NOT SEND"
exit $rc
