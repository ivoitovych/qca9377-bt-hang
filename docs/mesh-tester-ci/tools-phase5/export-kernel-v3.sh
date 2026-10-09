#!/bin/bash
# export-kernel-v3.sh <tip> - phase 5 §G: export the kernel sequence
# 08e90633377f..<tip> from cache/mesh-guest into series-v3/ (0000 cover template,
# 000N patches, base-commit) and the commit messages as msg-000N.txt.
# Refuses if a 000*.patch already exists there.
set -euo pipefail
G=/root/exp/qca9377-bt-hang/cache/mesh-guest
O=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-v3
BASE=08e90633377f
TIP=${1:?tip commit}
for f in "$O"/000*.patch; do
	if [ -e "$f" ]; then echo "refusing: $f exists"; exit 1; fi
done
git -C "$G" format-patch --cover-letter --base="$BASE" -o "$O" "$BASE..$TIP"
i=1
for c in $(git -C "$G" rev-list --reverse "$BASE..$TIP"); do
	git -C "$G" log -1 --format=%B "$c" > "$O/msg-000$i.txt"
	echo "msg-000$i.txt <- $(git -C "$G" log -1 --format='%h %s' "$c")"
	i=$((i + 1))
done
