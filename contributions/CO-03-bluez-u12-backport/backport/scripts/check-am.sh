#!/bin/sh
# T004: the git format-patch series applies with git am to a fresh clone of
# the import (tag import/5.72-0ubuntu5.8), and the result equals the branch.
set -eu
top=/root/exp/agent-work/co03
d=$top/tmp/am-check
rm -rf "$d"
mkdir -p "$top/tmp"
git clone -q "$top/src/bluez" "$d"
cd "$d"
git config user.name "Iaroslav Voitovych"
git config user.email "yaroslav.voytovych@gmail.com"
git checkout -q -b am-check import/5.72-0ubuntu5.8
git am -q "$top"/format-patch/*.patch
git log --oneline import/5.72-0ubuntu5.8..HEAD
echo "tree diff against origin/co03/u12-backport:"
git diff --stat origin/co03/u12-backport HEAD
echo "end of diff"
