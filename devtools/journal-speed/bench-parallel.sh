#!/bin/bash
# bench-parallel.sh — the whole journal, every file read on its own, in parallel, kernel
# messages only, counted with grep. Compare with bench.sh's merged read. Read-only.
set -u
D=/var/log/journal/fe39f92475564dc19f9053ec0b0605f6
RE='command( 0x[0-9a-f]+)? tx timeout'
P=${1:-$(nproc)}
t0=$(date +%s.%N)
lines=$(find "$D" -maxdepth 1 -name 'system*.journal' -print0 \
	| xargs -0 -P "$P" -I{} sh -c 'journalctl --file="$1" -k --no-pager -q -o cat | wc -l' _ {} \
	| awk '{s+=$1} END {print s}')
t1=$(date +%s.%N)
echo "all system files, -k, $P in parallel: $(echo "$t1 - $t0" | bc) s  kernel lines=$lines"
t0=$(date +%s.%N)
hits=$(find "$D" -maxdepth 1 -name 'system*.journal' -print0 \
	| xargs -0 -P "$P" -I{} sh -c 'journalctl --file="$1" -k --no-pager -q -o cat | grep -cE "$2"' _ {} "$RE" \
	| awk '{s+=$1} END {print s}')
t1=$(date +%s.%N)
echo "same, counting HCI command timeouts:  $(echo "$t1 - $t0" | bc) s  hits=$hits"
