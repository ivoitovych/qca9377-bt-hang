#!/bin/bash
# Part 1: e2, p2, g2 and the two combined builds on the same sets as before, 3 runs, lowest priority, one at a time.
export W=$WORKDIR
export ENVNAME=host REALGLOB='/var/log/journal/*/'
export VARS="e2 p2 g2 pg2a pg2b"
M=$W/bin/measure-runs.sh
run() { nice -n 19 ionice -c 3 $M; }
OUT=$W/pg-synth-seq.tsv WHAT=synth KS="25 50 100 200 400 800" run
OUT=$W/pg-synth-int1.tsv WHAT=synth LABEL=_int1 SETROOT=$W/data/inter-sets/int1 KS="25 50 100 200 400" run
OUT=$W/pg-synth-int3m.tsv WHAT=synth LABEL=_int3m SETROOT=$W/data/inter-sets/int3m KS="25 50 100 200 400" run
OUT=$W/pg-synth-seq-full.tsv WHAT=synth LABEL=_full LINES=2000000 SECS=150 KS="100 400 800" run
echo HOSTPGDONE
