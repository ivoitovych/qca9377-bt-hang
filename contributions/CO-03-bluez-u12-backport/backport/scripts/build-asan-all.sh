#!/bin/sh
# ASan/UBSan builds and sanitized make check of base and backport, in turn.
set -u
for n in ${*:-base backport}; do
    echo "== $n $(date -Is)"
    /root/exp/agent-work/co03/scripts/build-asan.sh "$n"
done
echo "== done $(date -Is)"
