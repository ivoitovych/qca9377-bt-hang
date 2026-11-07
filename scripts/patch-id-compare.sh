#!/bin/bash
# patch-id-compare.sh <git dir> <a> <b> - the stable patch-id of two changes,
# each given as a commit or as a patch/mbox file, and whether they are equal.
# Equal ids mean the same diff, independent of line offsets and blob ids; a
# backport whose context or code was adapted gets a different id.
set -u
G=${1:?usage: patch-id-compare.sh <git dir> <a> <b>}
A=${2:?usage: patch-id-compare.sh <git dir> <a> <b>}
B=${3:?usage: patch-id-compare.sh <git dir> <a> <b>}

pid() {
	if [[ -f "$1" ]]; then
		git -C "$G" patch-id --stable < "$1" | cut -d' ' -f1
	else
		git -C "$G" show --format= "$1" | git -C "$G" patch-id --stable | cut -d' ' -f1
	fi
}

a=$(pid "$A"); b=$(pid "$B")
echo "$a  $A"
echo "$b  $B"
if [[ -n "$a" && "$a" == "$b" ]]; then echo "SAME"; else echo "DIFFERENT"; fi
