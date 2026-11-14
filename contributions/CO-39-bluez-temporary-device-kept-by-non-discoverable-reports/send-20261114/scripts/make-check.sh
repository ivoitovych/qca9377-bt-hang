#!/bin/sh
# make check of work/<tree> (already built) in the build container; log logs/check-<tree>.log
set -u
top=/root/exp/agent-work/lane4-bluez-20261114/co39
t=$1
echo "make-check.sh $t start $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
docker run --rm --name "lane4-co39-check-$t" -v "$top/work/$t:/b" -w /b co03-noble-build:1 sh -c "
make -j4 check; echo \"make check exit \$?\"" \
    > "$top/logs/check-$t.log" 2>&1
echo "make-check.sh $t end $(date +%H:%M:%S)" >> "$top/PROGRESS.log"
tail -25 "$top/logs/check-$t.log"
