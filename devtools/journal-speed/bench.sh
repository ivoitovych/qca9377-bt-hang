#!/bin/bash
# bench.sh — how fast can the kernel journal be counted? One window of boot -1, three ways.
# Read-only. Prints seconds and the count for each method, so the methods are checked
# against each other as well as timed.
set -u
S=${1:-"2026-10-22 09:00"}
U=${2:-"2026-10-22 12:00"}
RE='command( 0x[0-9a-f]+)? tx timeout|Setup Synchronous|opcode 0x0428'
OUT=/root/exp/qca9377-bt-hang/tmp/journal-speed
cd "$OUT" || exit 1
echo "window: $S .. $U"

t0=$(date +%s.%N)
n=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q --grep="$RE" | wc -l)
t1=$(date +%s.%N)
echo "A journalctl --grep:          $(echo "$t1 - $t0" | bc) s  lines=$n"

t0=$(date +%s.%N)
n=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q -o cat | grep -cE "$RE")
t1=$(date +%s.%N)
echo "B journalctl -o cat | grep:   $(echo "$t1 - $t0" | bc) s  lines=$n"

t0=$(date +%s.%N)
total=$(journalctl -k -b -1 -S "$S" -U "$U" --no-pager -q -o cat | wc -l)
t1=$(date +%s.%N)
echo "  kernel lines in window:     $total ($(echo "$t1 - $t0" | bc) s to read them)"

t0=$(date +%s.%N)
all=$(journalctl -b -1 -S "$S" -U "$U" --no-pager -q -o cat | wc -l)
t1=$(date +%s.%N)
echo "  all lines in window:        $all ($(echo "$t1 - $t0" | bc) s)"
