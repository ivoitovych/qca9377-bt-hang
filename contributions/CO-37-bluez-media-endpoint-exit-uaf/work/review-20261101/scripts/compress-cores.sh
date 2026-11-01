#!/bin/bash
# Compress (never delete) the ASan core dumps the test harness copied into
# this work area, once they are at least 3 minutes old (not being
# written): <core> -> <core>.zst, verified by zstd before the original
# is removed (--rm only after a successful write). Lists each file with
# sizes before and after; free space before and after.
set -u
W=/root/exp/agent-work/co23-co37-review-20261101
df -B1M --output=avail,size,used / | tail -1 | sed 's/^/before (avail size used, MB): /'
n=0
while IFS= read -r -d '' f; do
	s=$(stat -c %s "$f")
	if zstd -q -T4 --rm "$f" -o "$f.zst"; then
		zstd -q -t "$f.zst" || echo "VERIFY FAILED $f.zst"
		echo "$s $(stat -c %s "$f.zst") $f"
		n=$((n + 1))
	else
		echo "FAILED $f"
	fi
done < <(find "$W" -name '*.core' -type f -mmin +3 -print0)
echo "compressed $n files"
df -B1M --output=avail,size,used / | tail -1 | sed 's/^/after (avail size used, MB): /'
