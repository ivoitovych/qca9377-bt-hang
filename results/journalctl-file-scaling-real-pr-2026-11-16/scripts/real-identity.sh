#!/bin/bash
# Part 2: output identity on the newest 25 files of the real journal, read in place (--file=), never copied.
# Only counts and sha256 digests are printed. The newest file is live, so every read ends at a fixed time
# (--until) one hour back; the file list is made once for all variants and the whole check is repeated if a file vanished.
W=$WORKDIR
dir=$(ls -d /var/log/journal/*/ | head -1)
for attempt in 1 2 3; do
    mapfile -t files < <(ls -t "$dir"*.journal* | head -n 25)
    args=(); for f in "${files[@]}"; do args+=("--file=$f"); done
    T=$(( $(date +%s) - 3600 ))
    bad=0
    echo "attempt $attempt: ${#files[@]} files, end time T=now-3600s"
    for q in "" "-r"; do
        for v in e2 p2 g2 pg2a pg2b; do
            export LD_LIBRARY_PATH=$W/bins/$v
            out=$(nice -n 19 ionice -c 3 $W/bins/$v/journalctl --no-pager -o export --until=@$T $q "${args[@]}" 2> $W/last-id.err | tee >(grep -a -c '^__CURSOR=' > $W/last-id.count) | sha256sum | cut -c1-16)
            n=$(cat $W/last-id.count)
            if grep -q "Failed to open files" $W/last-id.err; then bad=1; fi
            echo "  ${q:-fwd} $v entries $n sha256 $out"
        done
    done
    [ $bad = 0 ] && break
    echo "a file vanished (rotation); repeating"
done
