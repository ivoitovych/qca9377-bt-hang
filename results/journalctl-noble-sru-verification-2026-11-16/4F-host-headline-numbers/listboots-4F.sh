#!/bin/bash
# 4F: `journalctl --list-boots` (also sos's --disk-usage is trivial), 10 alternating runs per build at 25/50/100 files, host.
W=<work dir>
TIMEFORMAT='%R'
printf 'set\tbuild\trun\trc\twall_s\n'
for set in sys-100 mixed-100 sys-50 sys-25; do
    for r in 1 2 3 4 5 6 7 8 9 10; do
        for who in stock patched; do
            if [ $who = stock ]; then jc=$W/pkgx/hjc-s819; else jc=$W/pkgx/hjc-p820; fi
            t=$( { time $jc --directory=$W/verify/data/4F/$set --no-pager --list-boots > /dev/null 2>&1 ; echo "rc=$?" >&2; } 2>&1 )
            set -- $t
            printf '%s\t%s\t%s\t%s\t%s\n' ${SETN:-$set} $who $r "${2#rc=}" "$1"
        done
    done
done
