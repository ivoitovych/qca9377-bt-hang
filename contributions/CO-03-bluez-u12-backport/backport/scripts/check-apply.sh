#!/bin/sh
# git apply --check of each exported upstream patch on the tree at HEAD
# (each one on its own, not cumulative).
set -u
tree=${1:-/root/exp/agent-work/co03/src/bluez}
for p in /root/exp/agent-work/co03/upstream-patches/*.patch; do
    echo "== $(basename "$p")"
    git -C "$tree" apply --check -v "$p" 2>&1 | grep -v '^Checking patch' || true
done
