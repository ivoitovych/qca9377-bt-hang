#!/bin/bash
# query-runs.sh : common journalctl queries, one at a time, lowest priority, read only.
#   ENVNAME, W, REALGLOB, WHAT (synth|real), VARS (default "a b"), RUNS (default 2), SECS (cap per run, default 120), OUT
# Output TSV: env variant what query lines seconds capped(0/1)
set -u
W=${W:?}; ENVNAME=${ENVNAME:?}; WHAT=${WHAT:?}; OUT=${OUT:?}
VARS=${VARS:-a b}; RUNS=${RUNS:-2}; SECS=${SECS:-120}
UNIT=${UNIT:-systemd-logind.service}
if [ "$WHAT" = synth ]; then
    args=(--directory="$W/data/synth/sets/${SYNTHK:-800}")
    since="@1700000200"          # inside the synthetic time range, shortly after its start
    rare='file 799 boot 159'     # one file's entries: a full scan with few hits
    unitq=(-u "$UNIT")           # no such unit in the synthetic set: shows the cost of an empty match
else
    dir=$(ls -d $REALGLOB | head -1)
    since=$(date -d '1 day ago' '+%Y-%m-%d %H:%M:%S')
    rare=${RARE:-zzqxjv_no_such_word}
    unitq=(-u "$UNIT")
fi
names=("-b" "-b -1" "-u unit" "--since 1 day before end" "-n 100" "-k -b" "--list-boots" "-g rare word")
[ -n "${QONLY:-}" ] && names=("$QONLY")
for v in $VARS; do
    export LD_LIBRARY_PATH=$W/bins/$v
    for name in "${names[@]}"; do
        case $name in
            "-b") qarr=(-b) ;;
            "-b -1") qarr=(-b -1) ;;
            "-u unit") qarr=("${unitq[@]}") ;;
            "--since 1 day before end") qarr=(--since "$since") ;;
            "-n 100") qarr=(-n 100) ;;
            "-k -b") qarr=(-k -b) ;;
            "--list-boots") qarr=(--list-boots) ;;
            "-g rare word") qarr=(-g "$rare") ;;
        esac
        for r in $(seq $RUNS); do
            for attempt in 1 2 3; do
                if [ "$WHAT" = real ]; then
                    # the journal is live and rotates often: list the files just before each run, retry if one vanished
                    mapfile -t files < <(ls -t "$dir"*.journal* | head -n ${GK:-100000})
                    args=(); for f in "${files[@]}"; do args+=("--file=$f"); done
                fi
                t0=$(date +%s.%N)
                n=$(timeout $SECS nice -n 19 ionice -c 3 $W/bins/$v/journalctl --no-pager -o short "${args[@]}" "${qarr[@]}" 2>$W/last-query.err | wc -l)
                t1=$(date +%s.%N)
                grep -q "Failed to open files" $W/last-query.err || break
            done
            awk -v e=$ENVNAME -v v=$v -v w=$WHAT -v q="$name" -v n=$n -v a=$t0 -v b=$t1 -v cap=$SECS \
                'BEGIN{ s = b - a; printf "%s\t%s\t%s\t%s\t%d\t%.3f\t%d\n", e, v, w, q, n, s, (s >= cap - 0.5) }' | tee -a $OUT
        done
    done
done
