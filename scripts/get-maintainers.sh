#!/bin/bash
# get-maintainers.sh — the kernel's own recipient list for a patch file, run from
# inside a full kernel tree (scripts/get_maintainer.pl refuses to run elsewhere).
# For the "current recipients at send time" step of a kernel mail.
#
#   scripts/get-maintainers.sh <full-kernel-tree> <patch-file>
set -uo pipefail
TREE="${1:?full kernel tree}"; PATCH="${2:?patch file}"
# absolute BEFORE the cd: a relative patch path means nothing inside the tree
PATCH="$(readlink -f -- "$PATCH")"
[[ -r "$PATCH" ]] || { echo "cannot read patch file: $2" >&2; exit 2; }
cd "$TREE" || exit 2
perl scripts/get_maintainer.pl --no-git-fallback "$PATCH"
echo "-- roles --"
perl scripts/get_maintainer.pl --no-git-fallback --rolestats "$PATCH"
