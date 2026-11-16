#!/bin/bash
# 4B inside co46-verify:1: stock 8.19 and the 8.20 test build, archived files removed under an open reader.
set -u
cd /work/verify/bin
gcc -O1 -o reader reader.c -lsystemd || exit 1
REPS=${REPS:-6}
echo "build	reader	mode	victim	rep	K	removed	rc	entries	missing_surviving	dups	from_removed	order	messages"
for reader in jc-fwd jc-rev api-fwd api-bwd jc-follow; do
    for b in s819 p820; do python3 -I run4B.py $b $reader none current 3 7; done
    for mode in unlink dealloc truncate; do
        for victim in current future future2 past; do
            seed=$(( $(echo "$reader$mode$victim" | cksum | cut -d' ' -f1) % 100000 ))
            for b in s819 p820; do
                python3 -I run4B.py $b $reader $mode $victim $REPS $seed
            done
        done
    done
done
