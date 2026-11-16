#!/bin/bash
# 4D (old-format files written in a jammy container, then compared in the noble image) and 4E (imported/merged journals).
W=<work dir>
mkdir -p $W/verify/results
nice -n 19 docker run --rm --cpu-shares 256 -v $W:/work ubuntu:22.04 nice -n 19 ionice -c 3 /work/verify/bin/inside-4D-old.sh > $W/verify/results/4D-gen.txt 2>&1
$W/verify/bin/vk.sh inside-4D-test.sh > $W/verify/results/4D.txt 2>&1
$W/verify/bin/vk.sh inside-4E.sh > $W/verify/results/4E.txt 2>&1
echo 4DEDONE
