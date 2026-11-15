#!/bin/bash
# measure-scaling.sh JOURNALCTL DATADIR LABEL — journalctl's output rate as a function of the
# number of journal files it has open, on synthetic journals only.
#
# For K in KS (default 1 25 50 100 200 400): a directory holding the first K files of DATADIR
# (hard links), then `JOURNALCTL --directory=<it> -o cat --no-pager`, counted, never kept, for at
# most SECS seconds (default 15). Prints one line per K: label, K, lines, seconds, lines/s.
# Then, at K = STRACE_K (default 100), the system calls made while printing STRACE_N lines
# (default 20000), per printed line: fstat-family, clock_gettime, mmap/munmap, and all of them.
set -u
J=$1 D=$2 L=$3
KS=${KS:-1 25 50 100 200 400}; SECS=${SECS:-15}; SK=${STRACE_K:-100}; SN=${STRACE_N:-20000}
sets=$D.sets; mkdir -p "$sets"
mapfile -t all < <(ls "$D"/*.journal | sort)
for k in $KS; do
    [ -d "$sets/$k" ] && continue
    mkdir -p "$sets/$k"; for f in "${all[@]:0:$k}"; do ln "$f" "$sets/$k/"; done
done
for k in $KS; do
    t0=$(date +%s.%N)
    n=$(timeout "$SECS" "$J" --directory="$sets/$k" -o cat --no-pager 2>"$sets/err" | wc -l)
    t1=$(date +%s.%N)
    if [ "$n" -eq 0 ]; then echo "$L	K=$k	NO OUTPUT: $(head -c 300 "$sets/err")"; continue; fi
    awk -v l="$L" -v k="$k" -v n="$n" -v a="$t0" -v b="$t1" \
        'BEGIN { s = b - a; printf "%s\tK=%d\tlines=%d\tseconds=%.2f\tlines/s=%d\n", l, k, n, s, n / s }'
done
if [ -n "$SK" ] && command -v strace >/dev/null; then
    tr=$(mktemp)
    strace -f -c -o "$tr" "$J" --directory="$sets/$SK" -o cat --no-pager 2>/dev/null | head -n "$SN" > /dev/null
    awk -v l="$L" -v k="$SK" -v n="$SN" '
        $NF ~ /^(fstat|newfstatat|statx|fstatat64)$/ { st += $4 }
        $NF == "clock_gettime" { cl += $4 }
        $NF ~ /^(mmap|munmap)$/ { mm += $4 }
        $NF == "total" { tot = $4 }
        END { printf "%s\tK=%d\tper printed line: stat-family %.1f, clock_gettime %.1f, mmap+munmap %.2f, all syscalls %.1f (of %d lines)\n",
                     l, k, st / n, cl / n, mm / n, tot / n, n }' "$tr"
    rm -f "$tr"
fi
