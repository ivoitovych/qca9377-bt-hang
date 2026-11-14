#!/bin/bash
# One summary of every question: the final line of each .results file and the distinct ASan top frames.
W=/root/exp/agent-work/lane4-bluez-20261114/co37
out=$W/logs/results-summary.txt
{
    echo "co37 results, $(date '+%F %T')"
    for f in "$W"/runs/*/*.results; do
        d=$(basename "$(dirname "$f")")
        l=$(basename "$f" .results)
        echo "== $d / $l"
        tail -1 "$f"
        grep -o "top-frame \[[^]]*\]" "$f" | sort | uniq -c
        grep -c "exit 0 asan-reports 0" "$f" | sed 's/^/runs exit 0 and no ASan report: /'
    done
    echo
    for t in master series seriesB; do
        echo "make check $t: $(grep -E '^# (TOTAL|PASS|SKIP|FAIL):' "$W/runs/$t/make-check.log" | tr '\n' ' ')"
        echo "build warnings $t: $(grep -h warnings "$W/runs/$t/commits.txt")"
    done
} > "$out"
cat "$out"
