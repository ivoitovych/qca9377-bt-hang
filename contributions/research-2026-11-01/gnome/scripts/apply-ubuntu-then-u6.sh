#!/bin/bash
# apply-ubuntu-then-u6.sh: in a detached 46.7 worktree, apply Ubuntu's debian/patches
# series (46.7-0ubuntu0.24.04.6) in order, then the six upstream U6 commits, and report
# per patch APPLIED / FAILED. Changes only the worktree's files; no commits.
#
#   apply-ubuntu-then-u6.sh <worktree> <debian/patches dir> <u6 patch dir>
set -u
WT="$1"
PDIR="$2"
U6="$3"
fail=0
while IFS= read -r p; do
	case "$p" in ''|'#'*) continue ;; esac
	if git -C "$WT" apply "$PDIR/$p" 2>/dev/null; then
		echo "ubuntu APPLIED $p"
	else
		echo "ubuntu FAILED  $p"
		git -C "$WT" apply --check "$PDIR/$p" 2>&1 | sed 's/^/    /'
	fi
done < "$PDIR/series"
for p in "$U6"/0*.patch; do
	if git -C "$WT" apply --verbose "$p" > "$WT.u6-apply.log" 2>&1; then
		echo "u6     APPLIED $(basename "$p")"
	else
		echo "u6     FAILED  $(basename "$p")"
		sed 's/^/    /' "$WT.u6-apply.log"
		fail=1
	fi
done
git -C "$WT" diff --stat -- panels/sound
exit $fail
