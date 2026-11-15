#!/bin/bash
# Inside the container, the real journal mounted read-only at /rj. For K newest files (by mtime) and each
# variant in VARS: journalctl --file=... -o short, counted, never kept, for at most LINES lines or SECS seconds.
# Output TSV: variant K run lines seconds. No journal text is printed or stored.
set -u
W=/work
dir=$(ls -d /rj/*/ | head -1)
mapfile -t files < <(ls -t "$dir"*.journal*)
echo "files available: ${#files[@]}" >&2
VARS=${VARS:-a b d}; KS=${KS:-25 50 100 200 400 all}; RUNS=${RUNS:-2}
LINES=${LINES:-300000}; SECS=${SECS:-60}
out=${OUT:-$W/results-real.tsv}
for k in $KS; do
    [ "$k" = all ] && kk=${#files[@]} || kk=$k
    args=()
    for f in "${files[@]:0:$kk}"; do args+=("--file=$f"); done
    for v in $VARS; do
        for r in $(seq $RUNS); do
            export LD_LIBRARY_PATH=$W/bins/$v
            t0=$(date +%s.%N)
            n=$(timeout $SECS nice -n 19 ionice -c 3 $W/bins/$v/journalctl --no-pager -o short "${args[@]}" 2>/dev/null | head -n $LINES | wc -l)
            t1=$(date +%s.%N)
            awk -v v=$v -v k=$k -v kk=$kk -v r=$r -v n=$n -v a=$t0 -v b=$t1 'BEGIN{printf "%s\t%s(%d)\t%d\t%d\t%.3f\n", v,k,kk,r,n,b-a}' | tee -a $out
        done
    done
done
