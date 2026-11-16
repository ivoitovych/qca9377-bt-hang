#!/bin/bash
# Part 2: rates on the laptop's real journal for e2 p2 g2 pg2a pg2b (3 runs, median), then the identity check.
export W=$WORKDIR
export ENVNAME=host REALGLOB='/var/log/journal/*/'
export VARS="e2 p2 g2 pg2a pg2b"
OUT=$W/real-pr.tsv WHAT=real KS="25 50 100 200 all" nice -n 19 ionice -c 3 $W/bin/measure-runs.sh
nice -n 19 ionice -c 3 $W/bin/real-identity.sh > $W/real-identity.txt 2>&1
echo REALPRDONE
