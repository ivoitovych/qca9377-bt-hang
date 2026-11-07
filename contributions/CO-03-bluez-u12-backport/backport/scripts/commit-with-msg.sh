#!/bin/sh
# Commit all changes of the CO-03 tree with the author and author date of
# an upstream commit and a message read from a file.
# Usage: commit-with-msg.sh <upstream sha> <message file>
set -eu
tree=/root/exp/agent-work/co03/src/bluez
up=/root/exp/qca9377-bt-hang/cache/bluez-upstream
author="$(git -C "$up" log -1 --format='%an <%ae>' "$1")"
date="$(git -C "$up" log -1 --format='%aI' "$1")"
git -C "$tree" add -A
git -C "$tree" commit -q --author="$author" --date="$date" -F "$2"
git -C "$tree" log -1 --stat --format='%h %an %ad%n%B'
