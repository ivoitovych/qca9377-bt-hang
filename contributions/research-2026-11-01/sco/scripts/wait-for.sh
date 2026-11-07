#!/bin/bash
# wait-for.sh - print one line and exit when <file> contains <regex>, or after <seconds>.
# Usage: wait-for.sh <file> <regex> <seconds>
f=$1; re=$2; max=$3
for ((i = 0; i < max; i += 5)); do
	if grep -q -E "$re" "$f" 2>/dev/null; then
		echo "matched after ${i}s: $(grep -E "$re" "$f" | tail -n 1)"
		exit 0
	fi
	sleep 5
done
echo "timeout after ${max}s; last line: $(tail -n 1 "$f")"
exit 1
