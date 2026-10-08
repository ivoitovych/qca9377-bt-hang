#!/bin/bash
# copy-tree.sh — copy a file or directory tree inside the project, never over
# anything that exists.
#
#   scripts/copy-tree.sh <source> <destination>
#
# The destination must resolve under the project directory (worktrees in
# cache/ included); the source there or under /usr. The destination must not exist: a copy never merges into or
# overwrites an earlier state (never lose code, tests or evidence). Prints
# the file count copied.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
[ $# -eq 2 ] || { echo "usage: $0 <source> <destination>" >&2; exit 2; }
src=$(realpath -e -- "$1") || { echo "copy-tree: no such source: $1" >&2; exit 2; }
dst=$(realpath -m -- "$2")
# Sources may also come from /usr (distribution files such as libtool's
# ltmain.sh); the destination is always inside the project.
case "$src/" in
    "$REPO"/*|/usr/*) ;;
    *) echo "copy-tree: source outside the project and /usr: $src" >&2; exit 2 ;;
esac
case "$dst/" in
    "$REPO"/*) ;;
    *) echo "copy-tree: destination outside the project: $dst" >&2; exit 2 ;;
esac
if [ -e "$dst" ]; then
    echo "copy-tree: destination exists, refusing to overwrite: $dst" >&2
    exit 1
fi
mkdir -p -- "$(dirname -- "$dst")"
cp -a -- "$src" "$dst"
echo "copied $(find "$dst" -type f | wc -l) file(s): $src -> $dst"
