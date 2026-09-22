#!/bin/bash
# pre-send-check.sh — the check that was missing on 2026-09-21: before mailing a
# patch, fetch the upstream tree and look at TODAY'S master, not the checkout
# from a month ago. Both BlueZ v2 mails went out 6.5 h after the maintainer had
# applied v1 — visible in one `git fetch`. Read-only on the checkout.
#
#   scripts/pre-send-check.sh <tree> <mail-or-patch>...
#
# For each file: (1) is a commit with the same subject already on
# origin/master? (2) does the patch `git apply --check` against origin/master?
# A same-subject commit is reported as ALREADY APPLIED and the file fails the
# check even if the diff would still apply (a pure insertion applies twice).
set -uo pipefail
TREE="${1:?usage: pre-send-check.sh <tree> <patch>...}"; shift
(( $# )) || { echo "no patches given" >&2; exit 2; }
git -C "$TREE" fetch --quiet origin || { echo "fetch failed — do not send on a stale tree" >&2; exit 2; }
echo "origin/master: $(git -C "$TREE" log -1 --format='%h %cs %s' origin/master)"
rc=0
for p in "$@"; do
	subj=$(sed -n 's/^Subject: \(\[[^]]*\] \)*//p' "$p" | head -1)
	echo "── $(basename "$p")"
	echo "   subject: $subj"
	hit=$(git -C "$TREE" log --format='%h %cd %cn' --date=short -F --grep="$subj" origin/master | head -3)
	if [[ -n "$hit" ]]; then
		echo "   ALREADY APPLIED on origin/master:"
		printf '     %s\n' "$hit"
		rc=1
	fi
	# apply against origin/master without touching the working tree
	idx=$(mktemp) || exit 2
	if GIT_INDEX_FILE="$idx" git -C "$TREE" read-tree origin/master 2>/dev/null \
	   && GIT_INDEX_FILE="$idx" git -C "$TREE" apply --check --cached "$p" 2>"$idx.err"; then
		echo "   applies to origin/master: yes"
	else
		echo "   applies to origin/master: NO — $(head -1 "$idx.err")"
		rc=1
	fi
	rm -f "$idx" "$idx.err"
done
(( rc == 0 )) && echo "OK to send" || echo "DO NOT SEND"
exit $rc
