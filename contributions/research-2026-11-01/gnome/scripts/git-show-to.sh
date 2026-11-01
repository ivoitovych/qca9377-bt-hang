#!/bin/bash
# git-show-to.sh: write `git show <rev>:<path>` of a repository into a file (overwrites).
#   git-show-to.sh <repo> <rev>:<path> <out-file>
set -eu
git -C "$1" show "$2" > "$3"
echo "wrote $3 ($(wc -l < "$3") lines) from $2"
