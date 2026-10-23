#!/bin/bash
# bench-file.sh — read ONE archived journal file directly, to tell per-entry decoding
# cost from the cost of merging ~100 files. Read-only.
set -u
F=${1:?archived system journal file}
t0=$(date +%s.%N)
n=$(journalctl --file="$F" --no-pager -q -o cat | wc -l)
t1=$(date +%s.%N)
echo "one file, all entries, -o cat:  $(echo "$t1 - $t0" | bc) s  lines=$n"
t0=$(date +%s.%N)
n=$(journalctl --file="$F" -k --no-pager -q -o cat | wc -l)
t1=$(date +%s.%N)
echo "one file, -k, -o cat:           $(echo "$t1 - $t0" | bc) s  lines=$n"
t0=$(date +%s.%N)
n=$(journalctl --file="$F" --no-pager -q -o export | wc -c)
t1=$(date +%s.%N)
echo "one file, -o export (bytes):    $(echo "$t1 - $t0" | bc) s  bytes=$n"
ls -l "$F"
