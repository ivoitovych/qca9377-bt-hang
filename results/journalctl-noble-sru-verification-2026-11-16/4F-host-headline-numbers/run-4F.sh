#!/bin/bash
# 4F: copies, then the timing queries, then the strace check. One heavy job at a time, nice 19 / ionice -c 3.
W=<work dir>
V=$W/verify
nice -n 19 ionice -c 3 python3 -I $V/bin/prep-4F.py > $V/results/4F-prep.txt 2>&1
for s in mixed-25 sys-25 mixed-50 sys-50 mixed-100 sys-100; do
    nice -n 19 ionice -c 3 $V/bin/host-4F.sh $s >> $V/results/4F.tsv 2>> $V/results/4F.err
done
echo 4FDONE
