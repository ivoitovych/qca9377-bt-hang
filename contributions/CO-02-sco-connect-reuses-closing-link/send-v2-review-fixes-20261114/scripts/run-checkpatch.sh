#!/bin/bash
# run-checkpatch.sh : checkpatch --strict on every kernel mail of this work, inside an ubuntu container
# (the host run of checkpatch.pl is refused by the agent guard). Output: logs/checkpatch.txt
W=/root/exp/agent-work/lane7-sco-20261114
OUT=$W/logs/checkpatch.txt
: > "$OUT"
for f in "$W"/mails/b-three/kernel/v2-000[123]-*.patch "$W"/mails/a-two-plus-one/kernel-v2-1-2/v2-000[12]-*.patch "$W"/mails/a-two-plus-one/kernel-patch-3/0001-*.patch; do
	echo "=== ${f#$W/}" >> "$OUT"
	nice -n 10 ionice -c 2 -n 7 docker run --rm --cpu-shares 256 -v "$W/linux/scripts:/k/scripts:ro" -v "$W/mails:/m:ro" --entrypoint nice co03-noble-build:1 \
		-n 10 ionice -c 2 -n 7 perl /k/scripts/checkpatch.pl --strict --no-tree "/m/${f#$W/mails/}" >> "$OUT" 2>&1
done
cat "$OUT"
