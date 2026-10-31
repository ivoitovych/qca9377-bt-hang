#!/bin/sh
# Commit the staged/working changes of the CO-03 tree as a backport of an
# upstream commit: original author and author date, original message, then
# a "(backported from commit <sha>)" note and an optional adaptation note
# read from a file.
# Usage: backport-commit.sh <sha> [note-file]
set -eu
tree=/root/exp/agent-work/co03/src/bluez
up=/root/exp/qca9377-bt-hang/cache/bluez-upstream
sha=$(git -C "$up" rev-parse "$1")
msg=$(mktemp)
git -C "$up" log -1 --format=%B "$sha" | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' > "$msg"
printf '\n(backported from commit %s)\n' "$sha" >> "$msg"
if [ $# -ge 2 ]; then
    printf '[%s]\n' "$(cat "$2")" >> "$msg"
fi
author="$(git -C "$up" log -1 --format='%an <%ae>' "$sha")"
date="$(git -C "$up" log -1 --format='%aI' "$sha")"
git -C "$tree" add -A
git -C "$tree" commit -q --author="$author" --date="$date" -F "$msg"
rm -f "$msg"
git -C "$tree" log -1 --stat
