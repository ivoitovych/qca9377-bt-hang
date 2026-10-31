#!/bin/sh
# Apply one exported upstream patch to the CO-03 tree (git apply, optional
# --include path), without committing.
# Usage: backport-step.sh <sha12> [include-path]
set -eu
tree=/root/exp/agent-work/co03/src/bluez
p=/root/exp/agent-work/co03/upstream-patches/$1.patch
if [ $# -ge 2 ]; then
    git -C "$tree" apply -v --include="$2" "$p"
else
    git -C "$tree" apply -v "$p"
fi
git -C "$tree" status --short
