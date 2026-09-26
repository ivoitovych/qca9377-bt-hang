#!/bin/bash
# backport-check.sh — does a mainline commit already sit in, or apply cleanly to,
# each stable branch? For a stable backport request (stable-kernel-rules option 2:
# mail the commit id, the kernels and why, once it is in mainline).
#
#   scripts/backport-check.sh <commit> [<stable-branch>…]
#   default branches: stable/linux-{7.2,7.1,7.0,6.12,6.6,6.1}.y in cache/linux
#
# Per branch: PRESENT (a commit with the same subject is there), APPLIES (the
# patch applies to that branch's files; offset/fuzz shown), or FAILS. Read-only:
# the patch is tried on copies of the files in tmp/backport-check/, never on a
# checkout. Fetch first: git -C cache/linux fetch stable.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$HERE/cache/linux"
C="${1:?usage: backport-check.sh <commit> [<stable-branch>…]}"; shift
BRANCHES=("$@")
(( ${#BRANCHES[@]} )) || BRANCHES=(stable/linux-7.2.y stable/linux-7.1.y stable/linux-7.0.y stable/linux-6.12.y stable/linux-6.6.y stable/linux-6.1.y)
OUT="$HERE/tmp/backport-check"
rm -rf "$OUT"; mkdir -p "$OUT"
git -C "$REPO" format-patch -q -1 --stdout "$C" > "$OUT/patch" || exit 2
SUBJ=$(git -C "$REPO" log -1 --format=%s "$C")
mapfile -t FILES < <(git -C "$REPO" show --format= --name-only "$C")
echo "commit:  $(git -C "$REPO" log -1 --format='%h %s' "$C")"
echo "in:      $(git -C "$REPO" tag --contains "$C" --list 'v*' | head -1 || echo 'no release tag')"
echo "files:   ${FILES[*]}"
rc=0
for b in "${BRANCHES[@]}"; do
	tip=$(git -C "$REPO" log -1 --format='%h %s' "$b" 2>/dev/null) || { printf '%-22s ? no such branch\n' "$b"; rc=1; continue; }
	if git -C "$REPO" log --oneline -F --grep="$SUBJ" "$b" | grep -q .; then
		printf '%-22s PRESENT  (%s)\n' "$b" "$(git -C "$REPO" log -1 --format=%h -F --grep="$SUBJ" "$b")"
		continue
	fi
	d="$OUT/${b//\//_}"; mkdir -p "$d"
	for f in "${FILES[@]}"; do
		mkdir -p "$d/$(dirname "$f")"
		git -C "$REPO" show "$b:$f" > "$d/$f" 2>/dev/null || : > "$d/$f"
	done
	if res=$(patch -p1 --dry-run -d "$d" < "$OUT/patch" 2>&1); then
		printf '%-22s APPLIES  %s   [tip %s]\n' "$b" "$(grep -oE 'offset [-0-9]+ lines?|fuzz [0-9]+' <<<"$res" | tr '\n' ' ')" "${tip%% *}"
	else
		printf '%-22s FAILS    %s\n' "$b" "$(grep -m1 -E 'FAILED|malformed' <<<"$res")"
		rc=1
	fi
done
exit "$rc"
