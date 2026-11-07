#!/bin/sh
# checkpatch (--no-tree) on both patches, run in a container (read-only mounts).
# The requested tree cache/linux-bt-next does not exist; cache/full-bt-next is
# the Linux bluetooth-next checkout used instead.
top=/root/exp/agent-work/u29-t3-lifetime-patch
ck=/root/exp/qca9377-bt-hang/cache/full-bt-next/scripts
out=$top/logs/checkpatch.log
: > "$out"
for p in "$top"/patch/0001-*.patch "$top"/patch/5.72/0001-*.patch; do
    echo "=== $p" >> "$out"
    docker run --rm -v "$ck:/s:ro" -v "$top/patch:/p:ro" co03-noble-build:1 \
        perl /s/checkpatch.pl --no-tree "/p/${p#$top/patch/}" >> "$out" 2>&1
    echo "=== with --no-signoff" >> "$out"
    docker run --rm -v "$ck:/s:ro" -v "$top/patch:/p:ro" co03-noble-build:1 \
        perl /s/checkpatch.pl --no-tree --no-signoff "/p/${p#$top/patch/}" >> "$out" 2>&1
done
cat "$out"
