#!/bin/bash
# get-maintainers.sh — the kernel's own recipient list for a patch file, run from
# inside a full kernel tree (scripts/get_maintainer.pl refuses to run elsewhere).
# For the "current recipients at send time" step of a kernel mail.
#
#   scripts/get-maintainers.sh <full-kernel-tree> <patch-file>
set -uo pipefail
TREE="${1:?full kernel tree}"; PATCH="${2:?patch file}"
cd "$TREE" || exit 2
perl scripts/get_maintainer.pl --no-git-fallback "$PATCH"
echo "-- roles --"
perl scripts/get_maintainer.pl --no-git-fallback --rolestats "$PATCH"
