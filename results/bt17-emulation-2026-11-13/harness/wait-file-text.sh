#!/bin/bash
# wait-file-text.sh <file> <regex>: waits up to 170 s for the file to contain the regex; prints the file
# (or "still waiting" and the last line), so one call fits the foreground limit
f=${1:?usage}
for i in $(seq 17); do
	[ -e "$f" ] && grep -q -E "${2:?usage}" "$f" && { cat "$f"; exit 0; }
	sleep 10
done
echo "still waiting; last line: $(tail -n 1 "$f" | cut -c1-150)"
