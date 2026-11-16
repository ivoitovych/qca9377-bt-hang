#!/bin/bash
# Part 3 driver: one container per journal set, one after the other. run-noble.sh SETNAME...
W=$WORKDIR
R=$REPO
for s in "$@"; do
    echo "=== $s $(date +%H:%M)"
    docker run --rm --cpus=2 -e CAP=${CAP:-600} \
        -v $W:/work -v $W/data/noble-default/$s:/var/log/journal/6f1c2a9d4b8e4f3aa1c5d7e9b0a2c4e6:ro \
        ubuntu:24.04 nice -n 19 ionice -c 3 /work/bin/inside-noble-root.sh $s > $W/noble-$s.out 2>&1
    grep '^#' $W/noble-$s.out
    grep -v '^#' $W/noble-$s.out | grep -P '^[a-z0-9-]+\t' >> $W/noble-results.tsv
done
echo NOBLEDONE
