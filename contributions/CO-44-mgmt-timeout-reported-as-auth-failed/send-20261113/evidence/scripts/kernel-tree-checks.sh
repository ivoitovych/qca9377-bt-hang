#!/bin/bash
# usage: kernel-tree-checks.sh <patch> <out prefix>
# checkpatch --strict and get_maintainer.pl from inside the bluetooth-next tree (so the Fixes:
# commit resolves), both with the tree's own scripts at its checked-out commit.
set -u
L=/root/exp/agent-work/co44-send-20261113/linux
P=$(realpath -e "$1") || exit 2
O=$2
cd "$L" || exit 2
{
	echo "tree: $(git log -1 --format='%H %s')"
	echo "\$ scripts/checkpatch.pl --strict $P"
	scripts/checkpatch.pl --strict "$P"
	echo "exit $?"
} > "$O-checkpatch.txt" 2>&1
{
	echo "tree: $(git log -1 --format='%H %s')"
	echo "\$ scripts/get_maintainer.pl $P"
	scripts/get_maintainer.pl "$P"
	echo "exit $?"
} > "$O-get_maintainer.txt" 2>&1
cat "$O-checkpatch.txt" "$O-get_maintainer.txt"
