#!/bin/bash
# recount-co43-stable.sh: independent recount of the CO-43 1/3 stable-line runs from the raw logs.
#   per line and variant: kmemleak "unreferenced object" totals over the k-* and multi-* logs,
#   logs with any kernel report (same pattern as the agent), and the tree-diff file sizes.
set -u
d=${CO43_WORK}
pat='BUG:|WARNING:|KASAN|possible circular locking|possible recursive locking|inconsistent lock state|blocked for more than|soft lockup|workqueue lockup|general protection fault|Oops|suspicious RCU usage|UBSAN|refcount_t:|list_add corruption|list_del corruption|use-after-free|kernel BUG|DEADLOCK|lock held when returning|sleeping function called'
printf '%-6s %-5s %6s %8s %10s %8s\n' line var logs kml-objs report-logs healthy
for l in 7.3 6.18 6.12 6.6 6.1 5.15 5.10; do
    for v in base p1; do
        n=0; obj=0; rep=0
        for f in "$d"/logs/runs/s$l-$v-k-*.log "$d"/logs/runs/s$l-$v-multi-*.log; do
            [ -e "$f" ] || continue
            n=$((n + 1))
            obj=$((obj + $(grep -a -c 'unreferenced object' "$f")))
        done
        for f in "$d"/logs/runs/s$l-$v-*.log; do
            grep -a -q -E "$pat" "$f" && rep=$((rep + 1))
        done
        h=$(grep -a -c 'unreferenced object' "$d/logs/runs/s$l-$v-k-healthy-1.log")
        printf '%-6s %-5s %6s %8s %10s %8s\n' "$l" "$v" "$n" "$obj" "$rep" "$h"
    done
done
echo "tree-diff sizes (bytes):"
for l in 7.3 6.18 6.12 6.6 6.1 5.15 5.10; do
    printf '  %s %s\n' "$l" "$(stat -c %s "$d/logs/extra/tree-diff-$l.txt" 2>/dev/null || echo missing)"
done
echo "kinds of report on 5.10/5.15:"
grep -a -h -o -E "$pat" "$d"/logs/runs/s5.1[05]-*.log | sort | uniq -c
