#!/bin/bash
# gates-static.sh - phase 5 §G: the static gates on the exported final sequence.
#   1. kernel checkpatch --strict --codespell on the patch files (outside a tree,
#      so UNKNOWN_COMMIT_ID is ignored; the in-tree run of step 4 resolves Fixes:)
#   2. BlueZ gitlint (BlueZ's .gitlint) on the four BlueZ patches
#   3. BlueZ checkpatch under BlueZ's .checkpatch.conf
#   4. per-commit kernel preflight in cache/full-bt-next (checkpatch -g HEAD,
#      W=1 -Werror, sparse new-vs-base, recipients), tip first
# Output: stdout (captured by the caller into logs/phase5).
set -u
R=/root/exp/qca9377-bt-hang
exec > "$R/tmp/mesh-tester-ci/logs/phase5/gates-static.log" 2>&1
O=$R/tmp/mesh-tester-ci/series-v3
FT=$R/cache/full-bt-next
CP=$FT/scripts/checkpatch.pl

echo "### 1. kernel checkpatch --strict --codespell $(date '+%F %T')"
which codespell
for p in "$O"/000[1-9]-*.patch "$O"/alternative/0001-*.patch; do
	echo "== $(basename "$p")"
	perl "$CP" --strict --codespell --ignore UNKNOWN_COMMIT_ID "$p" | tail -n 4
done

echo "### 2. BlueZ gitlint $(date '+%F %T')"
"$R/scripts/gitlint-check.sh" "$R/cache/bluez-upstream" "$O"/bluez/000[1-9]-*.patch

echo "### 3. BlueZ checkpatch $(date '+%F %T')"
mkdir -p "$O/bluez-checkpatch-input"
cp "$O"/bluez/000[1-9]-*.patch "$O/bluez-checkpatch-input/"
BT_PATCH_DIR="$O/bluez-checkpatch-input" "$R/patches/bluez/checkpatch-check.sh" "$R/cache/bluez-upstream" "$CP"

echo "### 4. preflight $(date '+%F %T')"
git -C "$FT" checkout --detach 08e90633377f
git -C "$FT" am "$O"/000[1-9]-*.patch
git -C "$FT" log --oneline -6
for n in 0 1 2 3 4; do
	echo "== preflight at HEAD~0 after $n step(s) back $(date '+%F %T')"
	BT_SPARSE="$R/cache/sparse/sparse" "$R/scripts/kernel-preflight.sh" "$FT"
	echo "   (exit $?)"
	git -C "$FT" checkout --detach HEAD~1
done
git -C "$FT" checkout --detach HEAD@{5}
git -C "$FT" log --oneline -1
echo "### done $(date '+%F %T')"
