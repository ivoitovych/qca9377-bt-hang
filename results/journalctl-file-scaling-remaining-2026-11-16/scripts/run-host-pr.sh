#!/bin/bash
# Bare host, one run at a time, lowest priority: e2 (main at the PR base), p2 (+ PR #44579), g2 (+ our queue prototype).
export W=$WORKDIR
export ENVNAME=host REALGLOB='/var/log/journal/*/'
export VARS="e2 p2 g2"
M=$W/bin/measure-runs.sh
run() { nice -n 19 ionice -c 3 $M; }

OUT=$W/pr-synth-seq.tsv WHAT=synth KS="25 50 100 200 400 800" run
OUT=$W/pr-synth-int1.tsv WHAT=synth LABEL=_int1 SETROOT=$W/data/inter-sets/int1 KS="25 50 100 200 400" run
OUT=$W/pr-synth-int3m.tsv WHAT=synth LABEL=_int3m SETROOT=$W/data/inter-sets/int3m KS="25 50 100 200 400" run
# reverse and matches on the 400-file sequential set
OUT=$W/pr-synth-seq-queries.tsv WHAT=synth LABEL=_reverse EXTRA="-r" KS=400 run
OUT=$W/pr-synth-seq-queries.tsv WHAT=synth LABEL=_match_all EXTRA="SYSLOG_IDENTIFIER=kernel" KS=400 run
or=""
for b in $(seq 0 2 78); do
    id=$(printf '%08xb007b007b007b007b007b007' $b)
    [ -z "$or" ] && or="_BOOT_ID=$id" || or="$or + _BOOT_ID=$id"
done
OUT=$W/pr-synth-seq-queries.tsv WHAT=synth LABEL=_match_or40boots EXTRA="$or" KS=400 run
OUT=$W/pr-synth-int1-queries.tsv WHAT=synth LABEL=_int1_reverse SETROOT=$W/data/inter-sets/int1 EXTRA="-r" KS=400 run
OUT=$W/pr-real.tsv WHAT=real KS="25 50 100 200 400 all" run
echo HOSTPRDONE
