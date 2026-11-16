#!/bin/bash
# Smoke test on the host: first 50000 export lines of three sets, e2 against the others, digests only.
W=$WORKDIR
for set in $W/data/synth/sets/100 $W/data/inter-sets/int1/50 $W/data/inter-sets/int3m/100; do
    for v in e2 p2 g2 pg2a pg2b; do
        export LD_LIBRARY_PATH=$W/bins/$v
        h=$(nice -n 19 ionice -c 3 $W/bins/$v/journalctl --directory=$set --no-pager -o export 2>/dev/null | head -n 400000 | sha256sum | cut -c1-12)
        r=$(nice -n 19 ionice -c 3 $W/bins/$v/journalctl --directory=$set --no-pager -o export -r 2>/dev/null | head -n 400000 | sha256sum | cut -c1-12)
        echo "$(basename $(dirname $set))/$(basename $set) $v fwd $h rev $r"
    done
done
