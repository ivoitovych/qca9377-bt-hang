#!/bin/bash
# 4F structural check: system calls per printed line, stock against patched, at 100 files, on the host.
# strace -c -f counts every syscall of the process (and children); the output lines are counted separately.
# Queries print a fixed number of lines (-n N -o cat) so that the two builds print the same lines.
W=<work dir>
for set in sys-100 mixed-100; do
    for who in stock patched; do
        if [ $who = stock ]; then jc=$W/pkgx/hjc-s819; else jc=$W/pkgx/hjc-p820; fi
        for n in 3000 30000; do
            out=$W/verify/results/strace/$set.$who.$n
            mkdir -p $W/verify/results/strace
            [ -s $out.strace ] && continue
            strace -c -f -o $out.strace $jc --directory=$W/verify/data/4F/$set --no-pager -o cat -n $n > $out.out 2> $out.err
            rc=$?
            lines=$(wc -l < $out.out)
            echo "$set	$who	n=$n	rc=$rc	lines=$lines	$(awk '$NF ~ /^(fstat|newfstatat|statx|fstatfs)$/ {s += $4} END {print "fstat_family_calls=" s+0}' $out.strace)	$(awk '$NF == "total" {print "all_syscalls=" $4}' $out.strace)"
        done
    done
done
