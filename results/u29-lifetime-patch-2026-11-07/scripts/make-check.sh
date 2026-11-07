#!/bin/sh
# make check of a built tree, in a container. Usage: make-check.sh <tree>
# Log: logs/check-<tree>.log (full), test-suite.log copied to logs/check-<tree>-test-suite.log
set -u
top=/root/exp/agent-work/u29-t3-lifetime-patch
t=$1
echo "make-check.sh $t start $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
docker run --rm --name "u29t3-check-$t" -v "$top/work/$t:/b" -w /b co03-noble-build:1 sh -c "
make -j8 check; echo \"make check exit \$?\"" \
    > "$top/logs/check-$t.log" 2>&1
echo "make-check.sh $t end $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
tail -25 "$top/logs/check-$t.log"
