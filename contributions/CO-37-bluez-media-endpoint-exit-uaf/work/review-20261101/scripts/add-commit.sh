#!/bin/bash
# add-commit.sh <tree name> <commit>...
# Cherry-pick Python-only commits from ../repo into a built run tree
# (no rebuild needed) and note it in the tree's commits.txt.
set -eu
W=/root/exp/agent-work/co23-co37-review-20261101
d=$W/runs/$1/src
shift
git -C "$d" fetch --quiet origin '+refs/heads/*:refs/remotes/origin/*'
for c in "$@"; do
	git -C "$d" -c user.name=local -c user.email=local cherry-pick "$c" > /dev/null
	echo "added after build $(date '+%H:%M:%S'): $(git -C "$d" log -1 --format='%h %s')" | tee -a "$d/../commits.txt"
	git -C "$d" show --stat --format= HEAD
done
