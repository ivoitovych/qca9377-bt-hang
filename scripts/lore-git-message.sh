#!/bin/bash
# lore-git-message.sh — fetch one mail, by Message-ID, from lore's git archive of a list.
#
#   scripts/lore-git-message.sh <list> <message-id> [depth]     e.g. linux-bluetooth \
#       20261029013350.360574-1-yaroslav.voytovych@gmail.com
#
# WHY: lore's web pages and /raw answer this machine with a bot check (403, "Making sure you're
# not a bot!"), whatever the user agent; its git archive (public-inbox, one commit per mail, the
# raw message in the file "m") answers git over https. Found 2026-10-29, CO-25.
#
# Keeps a shallow bare clone per list in cache/lore-<list>-<epoch>.git (the newest epoch: the
# first N for which `git ls-remote` fails, minus one), fetches the newest [depth] (default 300)
# commits, and writes the first mail whose Message-ID header matches to
# tmp/lore-messages/<message-id>.eml; prints its path and archive commit. Read-only towards
# lore. Compare a sent file with it: scripts/mail-body-sha.py on both.
set -euo pipefail
LIST="${1:?usage: lore-git-message.sh <list> <message-id> [depth]}"
MSGID="${2:?usage: lore-git-message.sh <list> <message-id> [depth]}"
DEPTH="${3:-300}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MSGID="${MSGID#<}"; MSGID="${MSGID%>}"

epoch=0
while git ls-remote "https://lore.kernel.org/$LIST/$((epoch + 1))" >/dev/null 2>&1; do
	epoch=$((epoch + 1))
done
GITDIR="$REPO/cache/lore-$LIST-$epoch.git"
if [[ -d "$GITDIR" ]]; then
	git -C "$GITDIR" fetch -q --depth "$DEPTH" origin "+refs/heads/master:refs/heads/master"
else
	git clone -q --bare --depth "$DEPTH" "https://lore.kernel.org/$LIST/$epoch" "$GITDIR"
fi

OUT="$REPO/tmp/lore-messages/$MSGID.eml"
mkdir -p "$(dirname "$OUT")"
# The Message-ID header can be folded onto a second line (the patchwork bot's are), so the
# headers are parsed, not grepped.
has_id() {
	python3 -I -c 'import email, sys; m = email.message_from_binary_file(sys.stdin.buffer); sys.exit(0 if (m.get("Message-ID") or "").split() == ["<" + sys.argv[1] + ">"] else 1)' "$MSGID"
}
while read -r c; do
	if git -C "$GITDIR" cat-file blob "$c:m" 2>/dev/null | has_id; then
		git -C "$GITDIR" cat-file blob "$c:m" > "$OUT"
		echo "found: archive commit $c ($LIST epoch $epoch)"
		echo "-> $OUT"
		exit 0
	fi
done < <(git -C "$GITDIR" rev-list master)
echo "not found in the newest $DEPTH mails of $LIST epoch $epoch (not archived yet, or older: raise depth)"
exit 1
