#!/bin/bash
# kernel-regenerate.sh — rebuild the kernel patch mail on a full kernel worktree
# at a tree's tip: `git am` the current patch onto the worktree's HEAD, optionally
# replace the commit message, then `git format-patch -1 --base=HEAD~1`. The change
# must keep its patch-id, or the script fails.
#
#   scripts/kernel-regenerate.sh <worktree> <patch> [<message-file>]
#   e.g. scripts/kernel-regenerate.sh cache/full-bt tmp/review-kernel-0001/patches/kernel/0001-*.patch tmp/kernel-0001-msg-v4.txt
#
# Writes the new mail to tmp/kernel-regenerated/ and prints its path. The worktree
# is left with the patch commit at HEAD, which is what scripts/kernel-preflight.sh
# expects. The message file is the whole commit message (subject, body, trailers).
# Worktree must be clean and detached at the base (build-bluetooth-fulltree.sh leaves
# it so). Author identity: the operator's, as the sign-off.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TREE="${1:?usage: kernel-regenerate.sh <worktree> <patch> [<message-file>]}"
PATCH="${2:?usage: kernel-regenerate.sh <worktree> <patch> [<message-file>]}"
MSG="${3:-}"
[[ -r "$PATCH" ]] || { echo "cannot read $PATCH" >&2; exit 2; }
PATCH="$(readlink -f "$PATCH")"
if [[ -n "$MSG" ]]; then
	[[ -s "$MSG" ]] || { echo "empty or unreadable message file: $MSG" >&2; exit 2; }
	MSG="$(readlink -f "$MSG")"
fi
OUT="$HERE/tmp/kernel-regenerated"
ID=(-c user.name="Iaroslav Voitovych" -c user.email="yaroslav.voytovych@gmail.com")
cd "$TREE" || exit 2

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
	echo "worktree has tracked changes; refusing" >&2; exit 2
fi
echo "base: $(git log -1 --format='%h %cs %s' | cut -c1-90)"
git "${ID[@]}" am -q --committer-date-is-author-date "$PATCH" || { git am --abort; echo "git am failed" >&2; exit 1; }
if [[ -n "$MSG" ]]; then
	git "${ID[@]}" commit -q --amend -F "$MSG" || exit 1
fi

rm -rf "$OUT"; mkdir -p "$OUT"
git format-patch -q -1 --base=HEAD~1 --filename-max-length=120 -o "$OUT" HEAD || exit 1
NEW=$(ls "$OUT"/*.patch)

# the change must not have changed. The blob hashes on the index line and the
# hunk offsets legitimately differ between trees, so compare patch-ids (which
# ignore both), and show the +/- lines.
pid() { git patch-id --stable < "$1" | cut -d' ' -f1; }
OLD_ID=$(pid "$PATCH"); NEW_ID=$(pid "$NEW")
if [[ -z "$OLD_ID" || "$OLD_ID" != "$NEW_ID" ]]; then
	echo "✗ the change differs after regeneration (patch-id $OLD_ID vs $NEW_ID); not using it" >&2
	exit 1
fi
echo "✓ same change as $(basename "$PATCH") (patch-id ${NEW_ID:0:12})"
grep -E '^[-+][^-+]' "$NEW"
echo "commit: $(git log -1 --format='%h %s')"
echo "$(grep '^base-commit:' "$NEW")"
echo "-> $NEW"
