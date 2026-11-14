#!/bin/bash
# Run the kernel's get_maintainer.pl on files, from inside a kernel tree.
#   getmaint.sh <kernel-tree> <file>...
# Prints, per file: the default output, then --rolestats --git (history-based
# additions, last year of commits), so the difference is visible.
set -uo pipefail
TREE="${1:?kernel tree}"; shift
cd "$TREE" || exit 2
echo "tree: $TREE"
git log -1 --format='HEAD %H %cd' --date=iso
git show -s --format='MAINTAINERS from %H' da3cc0258
for f in "$@"; do
	echo "===== $f (default: --no-git-fallback)"
	perl scripts/get_maintainer.pl --no-git-fallback -f "$f"
	echo "===== $f (--rolestats --no-git-fallback)"
	perl scripts/get_maintainer.pl --no-git-fallback --rolestats -f "$f"
	echo "===== $f (--git --git-since 1-year-ago --rolestats)"
	perl scripts/get_maintainer.pl --git --git-since 1-year-ago --rolestats -f "$f"
done
