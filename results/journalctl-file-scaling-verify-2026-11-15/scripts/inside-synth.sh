#!/bin/bash
# Runs INSIDE the container. inside-synth.sh gen | run
# gen: synthetic journals, 800 files x EPF entries, archived.
# run: for variants VARS and K in KS, RUNS runs each: journalctl --directory=sets/K -o short, to
#      a line counter, for at most LINES lines or SECS seconds. TSV: variant K run lines seconds
set -u
W=/work
D=$W/data/synth
EPF=${EPF:-2000}
case ${1:-} in
gen)
    mkdir -p $D
    export LD_LIBRARY_PATH=$W/bins/a
    python3 -I /work/bin/make-journals-fixed.py $W/bins/a/systemd-journal-remote $D/all 800 $EPF 5
    for k in 25 50 100 200 400 800; do
        mkdir -p $D/sets/$k
        for f in $(ls $D/all/*.journal | sort | head -n $k); do ln -f $f $D/sets/$k/; done
    done
    du -sh $D/all
    ;;
run)
    VARS=${VARS:-a b c d}; KS=${KS:-25 50 100 200 400 800}; RUNS=${RUNS:-3}
    LINES=${LINES:-200000}; SECS=${SECS:-45}
    out=${OUT:-$W/results-synth.tsv}
    for k in $KS; do
      for v in $VARS; do
        for r in $(seq $RUNS); do
            export LD_LIBRARY_PATH=$W/bins/$v
            t0=$(date +%s.%N)
            n=$(timeout $SECS nice -n 19 $W/bins/$v/journalctl --directory=$D/sets/$k -o short --no-pager 2>/dev/null | head -n $LINES | wc -l)
            t1=$(date +%s.%N)
            awk -v v=$v -v k=$k -v r=$r -v n=$n -v a=$t0 -v b=$t1 'BEGIN{printf "%s\t%d\t%d\t%d\t%.3f\n", v,k,r,n,b-a}' | tee -a $out
        done
      done
    done
    ;;
esac
