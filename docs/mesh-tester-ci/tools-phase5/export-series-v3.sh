#!/bin/bash
# export-series-v3.sh - phase 5 §G: export the final sequence.
#   kernel:  cache/mesh-guest 08e90633377f..a4023e09b21d -> series-v3/000N-*.patch (+ 0000 cover template)
#   msgs:    series-v3/msg-000N.txt (the commit messages as committed)
#   bluez:   cache/bluez-upstream ae69dcddd..f620a4976 -> series-v3/bluez/000N-*.patch (+ cover template)
#   option1: the alternative deadline patch 99ccb3ab4861 -> series-v3/alternative/
# The cover letters are templates afterwards; their text is written by hand.
# Existing files are never overwritten: the script refuses if a target exists.
set -euo pipefail
G=/root/exp/qca9377-bt-hang/cache/mesh-guest
B=/root/exp/qca9377-bt-hang/cache/bluez-upstream
O=/root/exp/qca9377-bt-hang/tmp/mesh-tester-ci/series-v3
BASE=08e90633377f
TIP=a4023e09b21d
BBASE=ae69dcddd
BTIP=f620a4976

for f in "$O"/000*.patch "$O"/bluez/000*.patch "$O"/alternative/*.patch; do
	if [ -e "$f" ]; then echo "refusing: $f exists"; exit 1; fi
done

git -C "$G" format-patch --cover-letter --base="$BASE" -o "$O" "$BASE..$TIP"
i=1
for c in $(git -C "$G" rev-list --reverse "$BASE..$TIP"); do
	git -C "$G" log -1 --format=%B "$c" > "$O/msg-000$i.txt"
	echo "msg-000$i.txt <- $(git -C "$G" log -1 --format='%h %s' "$c")"
	i=$((i + 1))
done

mkdir -p "$O/bluez" "$O/alternative"
git -C "$B" format-patch --cover-letter --base="$BBASE" -o "$O/bluez" "$BBASE..$BTIP"
i=1
for c in $(git -C "$B" rev-list --reverse "$BBASE..$BTIP"); do
	git -C "$B" log -1 --format=%B "$c" > "$O/bluez/msg-000$i.txt"
	echo "bluez/msg-000$i.txt <- $(git -C "$B" log -1 --format='%h %s' "$c")"
	i=$((i + 1))
done

git -C "$G" format-patch --base=f40c7a65bcb2 -o "$O/alternative" -1 99ccb3ab4861
ls -la "$O" "$O/bluez" "$O/alternative"
