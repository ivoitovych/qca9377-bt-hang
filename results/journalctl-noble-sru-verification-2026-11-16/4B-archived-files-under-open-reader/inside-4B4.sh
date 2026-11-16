#!/bin/bash
# 4B, noise check: the cells flagged DIFFERENT in the first pass, 20 repetitions per build, fresh seeds.
set -u
cd /work/verify/bin
gcc -O1 -o reader reader.c -lsystemd || exit 1
echo "build	reader	mode	victim	rep	K	removed	rc	entries	missing_surviving	dups	from_removed	order	messages"
while read reader mode victim; do
    seed=$(( $(echo "4$reader$mode$victim" | cksum | cut -d' ' -f1) % 100000 ))
    for b in s819 p820; do python3 -I run4B.py $b $reader $mode $victim 20 $seed; done
done <<'EOT'
jc-rev dealloc current
jc-rev truncate future
jc-rev truncate current
jc-fwd dealloc future
jc-fwd truncate future
api-fwd dealloc future
api-fwd dealloc future2
api-bwd dealloc future
api-bwd dealloc future2
api-bwd truncate current
api-bwd truncate future
api-fwd truncate past
EOT
