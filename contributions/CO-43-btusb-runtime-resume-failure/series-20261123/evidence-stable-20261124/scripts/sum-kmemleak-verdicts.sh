#!/bin/bash
# sum-kmemleak-verdicts.sh: per line and variant, the harness's "KMEMLEAK after <case>: N unreferenced
# objects" values, listed per case in run order (the agent's table, recounted from the raw logs).
d=${CO43_WORK}/logs/runs
for l in 7.3 6.18 6.12 6.6 6.1 5.15 5.10; do
    for v in base p1; do
        printf '%-5s %-4s' "$l" "$v"
        for c in healthy-1 inject1 inject2 dead deadoff multi-cmdfirst; do
            vals=""
            for f in "$d"/s$l-$v-k-$c*.log "$d"/s$l-$v-$c*.log; do
                [ -e "$f" ] || continue
                case "$f" in *-r[0-9].log) ;; esac
                n=$(grep -a -o -E 'KMEMLEAK after [^:]*: [0-9]+ unreferenced' "$f" | tail -n 1 | grep -o -E '[0-9]+ unreferenced' | cut -d' ' -f1)
                vals="$vals${vals:+,}${n:-?}"
            done
            printf ' %s=%s' "$c" "$vals"
        done
        echo
    done
done
