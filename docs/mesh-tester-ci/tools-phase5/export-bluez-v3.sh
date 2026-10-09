#!/bin/bash
# export-bluez-v3.sh - phase 5 §G: export the BlueZ series (prefix "PATCH BlueZ")
# from cache/bluez-upstream ae69dcddd..<tip> into series-v3/bluez/, with the
# commit messages as msg-000N.txt. Refuses to overwrite.
set -euo pipefail
B=/root/exp/qca9377-bt-hang/cache/bluez-upstream
O=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-v3/bluez
BBASE=ae69dcddd
BTIP=${1:?tip commit}
if [ -e "$O" ]; then echo "refusing: $O exists"; exit 1; fi
mkdir -p "$O"
git -C "$B" format-patch --cover-letter --subject-prefix="PATCH BlueZ" --base="$BBASE" -o "$O" "$BBASE..$BTIP"
i=1
for c in $(git -C "$B" rev-list --reverse "$BBASE..$BTIP"); do
	git -C "$B" log -1 --format=%B "$c" > "$O/msg-000$i.txt"
	echo "msg-000$i.txt <- $(git -C "$B" log -1 --format='%h %s' "$c")"
	i=$((i + 1))
done
ls -la "$O"
