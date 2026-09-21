#!/bin/bash
# git-log-tab-count.sh — how many of the last N commits in a tree carry a hard
# tab, or a line over 75 columns, in their commit MESSAGE. Answers "does the
# maintainer apply messages the bot's GitLint/CheckPatch would fail?" from the
# tree itself. Read-only.
#
#   scripts/git-log-tab-count.sh <tree> [N] [--list]
set -uo pipefail
TREE="${1:?usage: git-log-tab-count.sh <tree> [N] [--list]}"
N="${2:-300}"
LIST="${3:-}"
REV="${BT_REV:-HEAD}"          # e.g. BT_REV=origin/master after a fetch
git -C "$TREE" log -1 --format='tree at %h  %cs' "$REV" || exit 2
git -C "$TREE" log -"$N" "$REV" --format='%x01%h%x02%an%x02%cn%x02%s%x02%b' | awk -v list="$LIST" '
	BEGIN { RS = "\001"; FS = "\002" }
	NR == 1 { next }
	{
		total++
		body = $5
		tab = index(body, "\t") > 0
		long = 0
		nl = split(body, L, "\n")
		for (i = 1; i <= nl; i++) if (length(L[i]) > 75) long = 1
		if (tab) tabs++
		if (long) longs++
		if (tab || long) either++
		if (list == "--list" && tab) printf "  TAB  %s  author=%s  committer=%s  %s\n", $1, $2, $3, $4
	}
	END {
		printf "commits examined:            %d\n", total
		printf "message has a hard tab:      %d\n", tabs
		printf "message has a line > 75:     %d\n", longs
		printf "either:                      %d\n", either
	}'
