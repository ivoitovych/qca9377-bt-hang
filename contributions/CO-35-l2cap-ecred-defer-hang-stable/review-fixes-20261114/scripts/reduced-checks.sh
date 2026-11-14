#!/bin/bash
# Size (diff lines, changed lines) and checkpatch (cache/checkpatch, --no-tree) of the reduced patches; the full
# mainline commits for comparison. Output: logs/reduced-checks.txt
R=/root/exp/qca9377-bt-hang
W=/root/exp/agent-work/lane4-bluez-20261114/stable-20261114
CP=$R/cache/checkpatch/checkpatch.pl
exec > "$W/logs/reduced-checks.txt" 2>&1
echo "checks $(date -u '+%F %T') UTC"
size() { # file: lines of the diff (from the first 'diff --git'), insertions, deletions
	local f=$1
	local d i x
	d=$(awk '/^diff --git/{p=1} /^-- $/{p=0} p' "$f" | wc -l)
	i=$(awk '/^diff --git/{p=1} /^-- $/{p=0} p && /^\+[^+]/' "$f" | wc -l)
	x=$(awk '/^diff --git/{p=1} /^-- $/{p=0} p && /^-[^-]/' "$f" | wc -l)
	echo "diff lines $d, insertions $i, deletions $x"
}
echo "== mainline 608e0b7a675b (the full prerequisite): $(size "$W/upstream/608e0b7a675b.patch")"
for l in 6.18.y 6.12.y 6.6.y 7.3.y; do
	f=$(ls "$W/reduced/$l"/0001-*.patch)
	echo "== reduced prerequisite $l: $(size "$f")"
	perl "$CP" --no-tree --no-color "$f"
	echo "rc=$?"
	f2=$(ls "$W/reduced/$l"/0002-*.patch)
	echo "== patch 2 $l: $(size "$f2")"
	perl "$CP" --no-tree --no-color "$f2"
	echo "rc=$?"
done
