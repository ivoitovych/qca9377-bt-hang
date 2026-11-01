#!/bin/bash
# Write lore archive messages to files, unchanged.
# Usage: lore-export.sh <bare lore repo> <out dir> <name>=<commit> ...
set -euo pipefail
repo=$1
out=$2
shift 2
mkdir -p "$out"
for pair in "$@"; do
	name=${pair%%=*}
	commit=${pair#*=}
	git -C "$repo" show "$commit:m" > "$out/$name"
	echo "$out/$name  $(sha256sum < "$out/$name" | cut -c1-16)  from lore $commit"
done
