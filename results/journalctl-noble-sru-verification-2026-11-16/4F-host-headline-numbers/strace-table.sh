#!/bin/bash
# strace-table.sh : table from the strace -c -f files written by strace-4F.sh (one .strace and .out per run).
# fstat family = fstat, newfstatat, statx, fstatfs; calls are column 4 of the strace -c table, the syscall name the last column.
D=<work dir>/verify/results/strace
printf 'set\tbuild\tprinted_lines\tfstat_family_calls\tall_syscalls\tfstat_calls_per_line\tall_syscalls_per_line\n'
for f in $D/*.strace; do
    b=$(basename $f .strace)
    set=${b%%.*}; rest=${b#*.}; who=${rest%%.*}; n=${rest#*.}
    lines=$(wc -l < $D/$b.out)
    fs=$(awk '$NF ~ /^(fstat|newfstatat|statx|fstatfs)$/ {s += $4} END {print s + 0}' $f)
    all=$(awk '$NF == "total" {print $4}' $f)
    [ "$lines" -gt 0 ] || continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $set $who $lines $fs $all $(( fs / lines )) $(( all / lines ))
done | sort
