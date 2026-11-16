#!/bin/bash
# measure-runs.sh : one run at a time, lowest priority, read only. Works on the bare host and inside the container.
#   ENVNAME   label written to the output (host or container)
#   W         work dir as seen by this process (host path, or /work in the container)
#   REALGLOB  glob of the real journal's directory, mounted/read as is (never copied, never written)
#   WHAT      synth | real
#   VARS KS RUNS LINES SECS OUT
# Output TSV: env variant what K run lines seconds io_some_total_delta_us
set -u
W=${W:?}; ENVNAME=${ENVNAME:?}; WHAT=${WHAT:?}
VARS=${VARS:-a b g}; RUNS=${RUNS:-3}; OUT=${OUT:?}
if [ "$WHAT" = synth ]; then
    KS=${KS:-25 50 100 200 400 800}; LINES=${LINES:-200000}; SECS=${SECS:-45}
else
    KS=${KS:-25 50 100 200 400 all}; LINES=${LINES:-300000}; SECS=${SECS:-60}; RUNS=${RUNS:-2}
    dir=$(ls -d $REALGLOB | head -1)
    mapfile -t files < <(ls -t "$dir"*.journal*)
fi
iosome() { awk '/^some/ { for (i = 1; i <= NF; i++) if ($i ~ /^total=/) { sub("total=", "", $i); print $i } }' /proc/pressure/io 2>/dev/null; }
for k in $KS; do
    for v in $VARS; do
        for r in $(seq $RUNS); do
            export LD_LIBRARY_PATH=$W/bins/$v
            for attempt in 1 2 3; do
                if [ "$WHAT" = synth ]; then
                    args=(--directory="$W/data/synth/sets/$k"); kk=$k
                else
                    # the journal is live (rotation, vacuum): list the files again just before each run, and
                    # start again (at most twice) if one of them was renamed or removed in between
                    mapfile -t files < <(ls -t "$dir"*.journal*)
                    [ "$k" = all ] && kk=${#files[@]} || kk=$k
                    args=(); for f in "${files[@]:0:$kk}"; do args+=("--file=$f"); done
                fi
                p0=$(iosome); t0=$(date +%s.%N)
                n=$(timeout $SECS nice -n 19 ionice -c 3 $W/bins/$v/journalctl --no-pager -o short "${args[@]}" 2>$W/last.err | head -n $LINES | wc -l)
                t1=$(date +%s.%N); p1=$(iosome)
                [ "$n" -gt 0 ] && break
            done
            awk -v e=$ENVNAME -v v=$v -v w=$WHAT -v k=$kk -v r=$r -v n=$n -v a=$t0 -v b=$t1 -v p0="${p0:-0}" -v p1="${p1:-0}" \
                'BEGIN{printf "%s\t%s\t%s\t%d\t%d\t%d\t%.3f\t%d\n", e,v,w,k,r,n,b-a,p1-p0}' | tee -a $OUT
        done
    done
done
