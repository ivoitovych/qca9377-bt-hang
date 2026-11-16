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
# exit status: 0 SAME, 1 DIFFERENT, 2 when a patch id could not be made (an empty id is no answer)
if [[ -z "$a" || -z "$b" ]]; then echo "NOT COMPARED: no patch id for $([[ -z "$a" ]] && echo "$A")$([[ -z "$b" ]] && echo " $B")" >&2; exit 2; fi
if [[ "$a" == "$b" ]]; then echo "SAME"; else echo "DIFFERENT"; exit 1; fi
